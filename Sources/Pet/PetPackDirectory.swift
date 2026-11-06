import Darwin
import Foundation

/// Descriptor-relative asset reads. No manifest member can escape this directory or execute a file.
final class PetPackDirectory {
    let descriptor: Int32
    private let privateFiles: Bool

    init(url: URL, create: Bool = false, privateFiles: Bool = false) throws {
        guard url.isFileURL, url.path.hasPrefix("/"), url.path.utf8.count <= 4096,
              url.standardizedFileURL.path == url.path else { throw PetPackFailure.unsafePath }
        var current = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard current >= 0 else { throw PetPackFailure.unreadable }
        do {
            let parts = url.path.split(separator: "/").map(String.init)
            guard !parts.isEmpty else { throw PetPackFailure.unsafePath }
            for (index, name) in parts.enumerated() {
                var created = false
                try Self.validName(name)
                var next = openat(current, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                if next < 0, errno == ENOENT, create {
                    if mkdirat(current, name, 0o700) == 0 { created = true }
                    else if errno != EEXIST { throw PetPackFailure.writeFailed }
                    next = openat(current, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                }
                guard next >= 0 else { throw errno == ENOENT ? PetPackFailure.missing : PetPackFailure.unsafePath }
                close(current)
                current = next
                if created && index == parts.count - 1 && privateFiles {
                    guard let acl = acl_init(0) else { throw PetPackFailure.writeFailed }
                    defer { acl_free(UnsafeMutableRawPointer(acl)) }
                    guard acl_set_fd(current, acl) == 0 else { throw PetPackFailure.writeFailed }
                }
            }
            if privateFiles { try Self.requirePrivate(current) }
            descriptor = current
            self.privateFiles = privateFiles
        } catch {
            close(current)
            throw error
        }
    }

    private init(descriptor: Int32, privateFiles: Bool) {
        self.descriptor = descriptor
        self.privateFiles = privateFiles
    }

    deinit { close(descriptor) }

    func child(_ name: String, create: Bool = false) throws -> PetPackDirectory {
        try Self.validName(name)
        if create {
            guard mkdirat(descriptor, name, 0o700) == 0 else { throw PetPackFailure.writeFailed }
        }
        let fd = openat(descriptor, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw errno == ENOENT ? PetPackFailure.missing : PetPackFailure.unsafePath }
        do {
            try Self.requirePrivate(fd)
            return PetPackDirectory(descriptor: fd, privateFiles: true)
        } catch {
            close(fd)
            throw error
        }
    }

    func read(_ name: String, limit: Int) throws -> Data {
        try Task.checkCancellation()
        try Self.validName(name)
        let fd = openat(descriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw errno == ENOENT ? PetPackFailure.missing : PetPackFailure.unreadable }
        defer { close(fd) }
        var before = stat()
        guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG, before.st_nlink == 1,
              before.st_size > 0, before.st_size <= off_t(limit) else { throw PetPackFailure.resourceLimit }
        if privateFiles { try Self.requirePrivate(fd) }
        let deadline = DispatchTime.now().uptimeNanoseconds + 3_000_000_000
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            try Task.checkCancellation()
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw PetPackFailure.unreadable }
            let count = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw PetPackFailure.unreadable }
            if count == 0 { break }
            guard result.count <= limit - count else { throw PetPackFailure.resourceLimit }
            result.append(contentsOf: buffer.prefix(count))
        }
        var after = stat()
        guard fstat(fd, &after) == 0, before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              before.st_size == after.st_size, before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec, result.count == Int(after.st_size) else {
            throw PetPackFailure.changed
        }
        return result
    }

    func write(_ name: String, data: Data) throws {
        try Self.validName(name)
        let fd = openat(descriptor, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw PetPackFailure.writeFailed }
        defer { close(fd) }
        guard let acl = acl_init(0) else { throw PetPackFailure.writeFailed }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        guard acl_set_fd(fd, acl) == 0 else { throw PetPackFailure.writeFailed }
        var offset = 0
        while offset < data.count {
            try Task.checkCancellation()
            let count = data.withUnsafeBytes { bytes in
                Darwin.write(fd, bytes.baseAddress?.advanced(by: offset), bytes.count - offset)
            }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw PetPackFailure.writeFailed }
            offset += count
        }
        guard fsync(fd) == 0 else { throw PetPackFailure.writeFailed }
    }

    func names() throws -> [String] {
        let copy = dup(descriptor)
        guard copy >= 0 else { throw PetPackFailure.unreadable }
        guard let stream = fdopendir(copy) else {
            close(copy)
            throw PetPackFailure.unreadable
        }
        defer { closedir(stream) }
        rewinddir(stream)
        var names: [String] = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw PetPackFailure.unreadable }
                break
            }
            try Task.checkCancellation()
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
            }
            if name == "." || name == ".." { continue }
            guard names.count < 256 else { throw PetPackFailure.resourceLimit }
            names.append(name)
        }
        return names
    }

    func synchronize() throws {
        guard fsync(descriptor) == 0 else { throw PetPackFailure.writeFailed }
    }

    func commit(stage: String, id: String) throws {
        try Self.validName(stage)
        try Self.validName(id)
        // The app-generated destination must not replace even an empty existing pack directory.
        guard renameatx_np(descriptor, stage, descriptor, id, UInt32(RENAME_EXCL)) == 0,
              fsync(descriptor) == 0 else { throw PetPackFailure.writeFailed }
    }

    func discardStage(_ name: String, files: [String]) {
        guard let stage = try? child(name) else { return }
        for file in files where (try? Self.validName(file)) != nil { _ = unlinkat(stage.descriptor, file, 0) }
        _ = unlinkat(descriptor, name, AT_REMOVEDIR)
    }

    private static func validName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", name.utf8.count <= 255,
              !name.contains("/"), !name.contains("\0") else { throw PetPackFailure.unsafePath }
    }

    private static func requirePrivate(_ fd: Int32) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw PetPackFailure.unsafePath
        }
        errno = 0
        guard let acl = acl_get_fd(fd) else {
            guard errno == ENOENT else { throw PetPackFailure.unsafePath }
            return
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        var entry: acl_entry_t?
        guard acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry) != 0 else { throw PetPackFailure.unsafePath }
    }
}
