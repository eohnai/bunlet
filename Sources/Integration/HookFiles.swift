import CryptoKit
import Darwin
import Foundation

public enum ProviderSetupFailure: String, Error, Equatable, Sendable {
    case unsafePath, unsafeMetadata, unreadable, resourceLimit, busy, changed
    case ownershipConflict, recoveryRequired, writeFailed, durabilityUncertain
    case unqualifiedVersion, enablementUnverified, hooksDisabled, managedHooksOnly, helperUnavailable
}

struct HookFileSnapshot {
    let data: Data?
    let device: UInt64
    let inode: UInt64
    let mode: mode_t
    let group: gid_t
    let modified: timespec
    let changed: timespec

    var digest: String? { data.map { Self.hash($0) } }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func same(as other: Self) -> Bool {
        data == other.data && device == other.device && inode == other.inode &&
        mode == other.mode && group == other.group &&
        modified.tv_sec == other.modified.tv_sec && modified.tv_nsec == other.modified.tv_nsec &&
        changed.tv_sec == other.changed.tv_sec && changed.tv_nsec == other.changed.tv_nsec
    }
}

/// Descriptor-relative I/O keeps symlinks out of every path component. Instances stay on one worker.
final class HookFileDirectory {
    static let byteLimit = 262_144
    let descriptor: Int32
    let url: URL
    let device: UInt64
    let inode: UInt64
    private let requiresPrivateDirectory: Bool

    init(_ url: URL, create: Bool = false, privateDirectory: Bool = false, allowRootOwner: Bool = false) throws {
        guard url.isFileURL, url.path.hasPrefix("/"), url.path.utf8.count <= 4096,
              url.standardizedFileURL.path == url.path,
              !url.path.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            throw ProviderSetupFailure.unsafePath
        }
        var current = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard current >= 0 else { throw ProviderSetupFailure.unreadable }
        do {
            let components = url.path.split(separator: "/").map(String.init)
            for (index, name) in components.enumerated() {
                var createdHere = false
                var next = openat(current, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                if next < 0, errno == ENOENT, create {
                    let result = mkdirat(current, name, 0o700)
                    guard result == 0 || errno == EEXIST else {
                        throw ProviderSetupFailure.writeFailed
                    }
                    createdHere = result == 0
                    try Self.synchronize(current)
                    next = openat(current, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                }
                guard next >= 0 else { throw ProviderSetupFailure.unsafePath }
                var info = stat()
                guard fstat(next, &info) == 0 else {
                    close(next)
                    throw ProviderSetupFailure.unreadable
                }
                let last = index == components.count - 1
                let trustedOwner = info.st_uid == getuid() || ((!last || allowRootOwner) && info.st_uid == 0)
                let sharedTemporaryRoot = !last && info.st_uid == 0 && info.st_mode & S_ISVTX != 0
                guard trustedOwner, info.st_mode & 0o022 == 0 || sharedTemporaryRoot,
                      !last || !privateDirectory || info.st_mode & 0o777 == 0o700 else {
                    close(next)
                    throw ProviderSetupFailure.unsafeMetadata
                }
                do {
                    if createdHere {
                        try Self.clearACL(next)
                        try Self.synchronize(next)
                    }
                    if last && privateDirectory { try Self.requirePrivateACL(next) }
                } catch {
                    close(next)
                    throw error
                }
                close(current)
                current = next
            }
            var info = stat()
            guard fstat(current, &info) == 0, info.st_uid == getuid() || (allowRootOwner && info.st_uid == 0) else {
                throw ProviderSetupFailure.unsafeMetadata
            }
            descriptor = current
            self.url = url
            device = UInt64(truncatingIfNeeded: info.st_dev)
            inode = UInt64(info.st_ino)
            requiresPrivateDirectory = privateDirectory
        } catch {
            close(current)
            throw error
        }
    }

    deinit { close(descriptor) }

    func recheckIdentity() throws {
        let current = try HookFileDirectory(url, privateDirectory: requiresPrivateDirectory)
        guard current.device == device, current.inode == inode else { throw ProviderSetupFailure.changed }
    }

    func read(_ name: String, privateFile: Bool = false) throws -> HookFileSnapshot {
        try Self.validateName(name)
        let fd = openat(descriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        if fd < 0 {
            guard errno == ENOENT else { throw ProviderSetupFailure.unsafePath }
            return HookFileSnapshot(data: nil, device: 0, inode: 0, mode: 0o600, group: getgid(),
                                    modified: timespec(), changed: timespec())
        }
        defer { close(fd) }
        var before = stat()
        guard fstat(fd, &before) == 0 else { throw ProviderSetupFailure.unreadable }
        try Self.validateFile(before, privateFile: privateFile)
        if privateFile { try Self.requirePrivateACL(fd) }
        // Replacement cannot preserve unknown extended metadata safely.
        guard flistxattr(fd, nil, 0, 0) == 0 else { throw ProviderSetupFailure.unsafeMetadata }
        guard before.st_size >= 0, before.st_size <= Self.byteLimit else { throw ProviderSetupFailure.resourceLimit }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        let deadline = DispatchTime.now().uptimeNanoseconds + 3_000_000_000
        while true {
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw ProviderSetupFailure.unreadable }
            let count = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw ProviderSetupFailure.unreadable
            }
            guard data.count <= Self.byteLimit - count else { throw ProviderSetupFailure.resourceLimit }
            data.append(contentsOf: buffer.prefix(count))
        }
        var after = stat()
        var named = stat()
        guard fstat(fd, &after) == 0,
              fstatat(descriptor, name, &named, AT_SYMLINK_NOFOLLOW) == 0,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              after.st_dev == named.st_dev, after.st_ino == named.st_ino,
              before.st_size == after.st_size, Int64(data.count) == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { throw ProviderSetupFailure.changed }
        return HookFileSnapshot(data: data, device: UInt64(truncatingIfNeeded: after.st_dev),
                                inode: UInt64(after.st_ino), mode: after.st_mode & 0o777,
                                group: after.st_gid, modified: after.st_mtimespec, changed: after.st_ctimespec)
    }

    @discardableResult
    func prepare(_ data: Data, name: String, preserving existing: HookFileSnapshot? = nil,
                 originalName: String? = nil) throws -> HookFileSnapshot {
        guard data.count <= Self.byteLimit else { throw ProviderSetupFailure.resourceLimit }
        try Self.validateName(name)
        let fd = openat(descriptor, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ProviderSetupFailure.writeFailed }
        var complete = false
        defer {
            if !complete {
                var opened = stat()
                var named = stat()
                if fstat(fd, &opened) == 0,
                   fstatat(descriptor, name, &named, AT_SYMLINK_NOFOLLOW) == 0,
                   opened.st_dev == named.st_dev, opened.st_ino == named.st_ino {
                    _ = unlinkat(descriptor, name, 0)
                }
            }
            close(fd)
        }
        if let existing, existing.data != nil, let originalName {
            guard fchown(fd, getuid(), existing.group) == 0, fchmod(fd, existing.mode) == 0 else {
                throw ProviderSetupFailure.unsafeMetadata
            }
            let original = openat(descriptor, originalName, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard original >= 0 else { throw ProviderSetupFailure.changed }
            defer { close(original) }
            var info = stat()
            guard fstat(original, &info) == 0, UInt64(info.st_ino) == existing.inode,
                  UInt64(truncatingIfNeeded: info.st_dev) == existing.device else { throw ProviderSetupFailure.changed }
            errno = 0
            if let acl = acl_get_fd(original) {
                defer { acl_free(acl) }
                guard acl_set_fd(fd, acl) == 0 else { throw ProviderSetupFailure.unsafeMetadata }
            } else if errno != ENOENT {
                throw ProviderSetupFailure.unsafeMetadata
            }
        } else {
            try Self.clearACL(fd)
        }
        var offset = 0
        let deadline = DispatchTime.now().uptimeNanoseconds + 3_000_000_000
        while offset < data.count {
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw ProviderSetupFailure.writeFailed }
            let count = data.withUnsafeBytes { bytes in
                Darwin.write(fd, bytes.baseAddress?.advanced(by: offset), data.count - offset)
            }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw ProviderSetupFailure.writeFailed }
            offset += count
        }
        try Self.synchronize(fd)
        let snapshot = try read(name)
        var prepared = stat()
        guard fstat(fd, &prepared) == 0, UInt64(prepared.st_ino) == snapshot.inode,
              UInt64(truncatingIfNeeded: prepared.st_dev) == snapshot.device else { throw ProviderSetupFailure.changed }
        complete = true
        return snapshot
    }

    func publish(_ temporary: String, as name: String, expected: HookFileSnapshot) throws {
        try Self.validateName(temporary)
        try Self.validateName(name)
        try recheckIdentity()
        guard expected.same(as: try read(temporary)) else { throw ProviderSetupFailure.changed }
        guard renameat(descriptor, temporary, descriptor, name) == 0 else { throw ProviderSetupFailure.writeFailed }
        try Self.synchronize(descriptor)
    }

    func replace(_ data: Data, name: String) throws {
        let temporary = ".notch-pet-\(UUID().uuidString).tmp"
        let prepared = try prepare(data, name: temporary)
        defer { discardTemporary(temporary, expected: prepared) }
        try publish(temporary, as: name, expected: prepared)
    }

    func discardTemporary(_ name: String, expected: HookFileSnapshot) {
        var named = stat()
        if fstatat(descriptor, name, &named, AT_SYMLINK_NOFOLLOW) == 0,
           UInt64(truncatingIfNeeded: named.st_dev) == expected.device, UInt64(named.st_ino) == expected.inode {
            _ = unlinkat(descriptor, name, 0)
        }
    }

    func remove(_ name: String) throws {
        try Self.validateName(name)
        try recheckIdentity()
        guard unlinkat(descriptor, name, 0) == 0 else { throw ProviderSetupFailure.changed }
        try Self.synchronize(descriptor)
    }

    func synchronizeFile(_ name: String, expected: HookFileSnapshot) throws {
        try Self.validateName(name)
        guard expected.same(as: try read(name)) else { throw ProviderSetupFailure.changed }
        let fd = openat(descriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw ProviderSetupFailure.unreadable }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, UInt64(info.st_ino) == expected.inode,
              UInt64(truncatingIfNeeded: info.st_dev) == expected.device else { throw ProviderSetupFailure.changed }
        try Self.synchronize(fd)
    }

    func lock() throws -> Int32 {
        let fd = openat(descriptor, "writer.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ProviderSetupFailure.unsafePath }
        var info = stat()
        do {
            guard fstat(fd, &info) == 0 else { throw ProviderSetupFailure.unreadable }
            try Self.validateFile(info, privateFile: true)
            try Self.requirePrivateACL(fd)
            guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw ProviderSetupFailure.busy }
            var named = stat()
            guard fstatat(descriptor, "writer.lock", &named, AT_SYMLINK_NOFOLLOW) == 0,
                  named.st_dev == info.st_dev, named.st_ino == info.st_ino else {
                throw ProviderSetupFailure.changed
            }
            try recheckIdentity()
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    private static func validateFile(_ info: stat, privateFile: Bool) throws {
        guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(), info.st_nlink == 1,
              info.st_mode & 0o7022 == 0, info.st_flags == 0,
              !privateFile || info.st_mode & 0o777 == 0o600 else { throw ProviderSetupFailure.unsafeMetadata }
    }

    private static func validateName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              !name.contains("\0"), name.utf8.count <= 255 else { throw ProviderSetupFailure.unsafePath }
    }

    static func exists(_ url: URL) throws -> Bool {
        var info = stat()
        if lstat(url.path, &info) != 0 {
            guard errno == ENOENT else { throw ProviderSetupFailure.unreadable }
            return false
        }
        guard info.st_mode & S_IFMT == S_IFDIR else { throw ProviderSetupFailure.unsafePath }
        return true
    }

    private static func clearACL(_ fd: Int32) throws {
        guard let acl = acl_init(0) else { throw ProviderSetupFailure.unsafeMetadata }
        defer { acl_free(acl) }
        guard acl_set_fd(fd, acl) == 0 else { throw ProviderSetupFailure.unsafeMetadata }
    }

    private static func requirePrivateACL(_ fd: Int32) throws {
        errno = 0
        guard let acl = acl_get_fd(fd) else {
            guard errno == ENOENT else { throw ProviderSetupFailure.unsafeMetadata }
            return
        }
        defer { acl_free(acl) }
        var entry: acl_entry_t?
        guard acl_get_entry(acl, ACL_FIRST_ENTRY, &entry) != 0 else {
            throw ProviderSetupFailure.unsafeMetadata
        }
    }

    static func synchronize(_ fd: Int32) throws {
        var result: Int32
        repeat { result = fsync(fd) } while result != 0 && errno == EINTR
        guard result == 0 else { throw ProviderSetupFailure.durabilityUncertain }
    }
}
