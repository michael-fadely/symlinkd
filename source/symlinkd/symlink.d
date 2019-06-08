module symlinkd.symlink;

import std.range;
import std.typecons;
import std.traits;

version (Windows)
{
	import core.sys.windows.windows;
	
	import std.internal.cstring : tempCString;

	import std.conv : to;
	import std.file : FileException;
	import std.path : isRooted;
	import std.string : startsWith;

	import symlinkd.windows;

	// TODO: actual support for Unicode (*W) functions?
	private enum prefix = `\\?\`;
}

/// Specifies the type of a symlink's target.
/// See_Also: createSymlink
enum SymlinkTargetType
{
	file,
	directory,
}

alias SymlinkCreateUnprivileged = Flag!"SymlinkCreateUnprivileged";

/**
	Creates a symbolic link.

	Params:
		target            = The filesystem object to create a link to.
		link              = The path to the new symbolic link.
		targetType        = Indicates the filesystem object type of `target`. Has no effect on non-Windows.
		allowUnprivileged = Windows only.
		                    Allows creation of symbolic links without administrative privileges.
		                    Developer Mode must be enabled on the system for it to function.

	Returns: `true` on success.

	See_Also: SymlinkTargetType
*/
bool createSymlink(TargetT, LinkT)(TargetT target, LinkT link, SymlinkTargetType targetType,
                                   SymlinkCreateUnprivileged allowUnprivileged = SymlinkCreateUnprivileged.no)
	if ((isInputRange!TargetT && !isInfinite!TargetT &&
	     isSomeChar!(ElementEncodingType!TargetT) || isConvertibleToString!TargetT) &&
		(isInputRange!LinkT && !isInfinite!LinkT && isSomeChar!(ElementEncodingType!LinkT) ||
		 isConvertibleToString!LinkT))
{
	version (Posix)
	{
		import std.file : symlink;
		symlink(target, link);
		return true;
	}
	else version (Windows)
	{
		static if (isConvertibleToString!TargetT || isConvertibleToString!LinkT)
		{
			import std.meta : staticMap;
			alias Types = staticMap!(convertToString, TargetT, LinkT);
			return symlink!Types(original, link);
		}
		else
		{
			DWORD flags = 0;

			if (targetType == SymlinkTargetType.directory)
			{
				flags |= SYMBOLIC_LINK_FLAG_DIRECTORY;
			}

			if (allowUnprivileged)
			{
				flags |= SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE;
			}

			// avoid MAX_PATH issues
			auto target_ = target.isRooted && !target.startsWith(prefix) ? prefix ~ target : target;
			auto link_   = link.isRooted && !link.startsWith(prefix) ? prefix ~ link : link;

			auto tz = target_.tempCString();
			auto lz = link_.tempCString();

			return !!CreateSymbolicLinkA(lz, tz, flags);
		}
	}
	else
	{
		static assert(false, __PRETTY_FUNCTION__ ~ " is not implemented on your platform!");
	}
}

alias SymlinkStripPrefix = Flag!"SymlinkStripPrefix";

/**
	Returns the path to a symbolic link's target.

	Params:
		link        = The path to the symbolic link.
		stripPrefix = Windows only. Strips `\\?\` from the path.

	Returns:
		The link's target.
*/
string readSymlink(R)(R link, SymlinkStripPrefix stripPrefix = SymlinkStripPrefix.yes)
if (isInputRange!R && !isInfinite!R && isSomeChar!(ElementEncodingType!R) || isConvertibleToString!R)
{
	version (Posix)
	{
		import std.file : readLink;
		return std.file.readLink(link);
	}
	else version (Windows)
	{
		static if (isConvertibleToString!R)
		{
			return readLink!(convertToString!R)(link);
		}
		else
		{
			auto strz = link.tempCString;
			auto handle = CreateFileA(strz, FILE_READ_EA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, null,
			                          OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, null);

			scope (exit) CloseHandle(handle);

			if (handle == INVALID_HANDLE_VALUE)
			{
				throw new FileException(link, "Unable to open file.");
			}

			const requiredLength = GetFinalPathNameByHandleA(handle, null, 0, 0);

			if (requiredLength < 1)
			{
				return null;
			}

			auto buffer = new char[requiredLength + 1];
			GetFinalPathNameByHandleA(handle, buffer.ptr, cast(uint)buffer.length, 0);

			auto result = to!string(buffer);

			if (stripPrefix && result.startsWith(prefix))
			{
				result = result[prefix.length .. $];
			}

			return result;
		}
	}
	else
	{
		static assert(false, __PRETTY_FUNCTION__ ~ " is not implemented on your platform!");
	}
}

// version (symlinkd_aliases)
// {
	public alias symlink  = createSymlink;
	public alias readLink = readSymlink;
// }
