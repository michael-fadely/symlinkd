module symlinkd.symlink;

import std.range;
import std.typecons;
import std.traits;

version (Windows)
{
	version (ANSI) {} else version = Unicode;

	import core.sys.windows.windows;

	import std.conv             : to;
	import std.file             : FileException;
	import std.internal.cstring : tempCString;
	import std.path             : isRooted;
	import std.string           : startsWith, fromStringz;
	import std.windows.syserror;

	import symlinkd.windows;

	// From std.file.d:
	// Character type used for operating system filesystem APIs
	private alias FSChar = WCHAR;       // WCHAR can be aliased to wchar or wchar_t

	private enum prefix = `\\?\`;

	// Avoid MAX_PATH issues by automatically prepending `\\?\`
	private auto asPrefixed(PathT)(PathT path)
	if (isInputRange!PathT && !isInfinite!PathT && isSomeChar!(ElementEncodingType!PathT))
	{
		if (path.isRooted && !path.startsWith(prefix))
		{
			// Windows API does not automatically replace '/' with '\'
			// when the prefix is present. .replace will do the right
			// thing and not allocate a copy of the string unless a
			// replacement actually occurs.
			return (prefix ~ path).replace(`/`, `\`);
		}

		return path;
	}
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

	See_Also: SymlinkTargetType
*/
void createSymlink(TargetT, LinkT)(TargetT target, LinkT link, SymlinkTargetType targetType,
                                   SymlinkCreateUnprivileged allowUnprivileged = SymlinkCreateUnprivileged.no)
if ((isInputRange!TargetT && !isInfinite!TargetT && isSomeChar!(ElementEncodingType!TargetT) || isConvertibleToString!TargetT) &&
    (isInputRange!LinkT && !isInfinite!LinkT && isSomeChar!(ElementEncodingType!LinkT) || isConvertibleToString!LinkT))
{
	version (Posix)
	{
		import std.file : symlink;
		symlink(target, link);
	}
	else version (Windows)
	{
		static if (isConvertibleToString!TargetT || isConvertibleToString!LinkT)
		{
			import std.meta : staticMap;
			alias Types = staticMap!(convertToString, TargetT, LinkT);
			createSymlink!Types(original, link);
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

			auto tz = target.asPrefixed().tempCString!(FSChar)();
			auto lz = link.asPrefixed().tempCString!(FSChar)();

			wenforce(CreateSymbolicLinkW(lz, tz, flags), "CreateSymbolicLinkW failed");
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
		import std.file;
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
			auto strz = link.asPrefixed().tempCString!(FSChar)();

			auto handle = CreateFileW(strz,
			                          FILE_READ_EA,
			                          FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
			                          null,
			                          OPEN_EXISTING,
			                          FILE_FLAG_BACKUP_SEMANTICS,
			                          null);

			scope (exit)
			{
				if (handle != INVALID_HANDLE_VALUE)
				{
					CloseHandle(handle);
				}
			}

			wenforce(handle != INVALID_HANDLE_VALUE, "CreateFileW failed");

			const requiredLength = GetFinalPathNameByHandleW(handle, null, 0, 0);
			wenforce(requiredLength > 0, "GetFinalPathNameByHandleW failed");

			auto buffer = new FSChar[requiredLength + 1];
			GetFinalPathNameByHandleW(handle, buffer.ptr, cast(uint)buffer.length, 0);
			wenforce(requiredLength > 0, "GetFinalPathNameByHandleW failed");

			string result = buffer.fromStringz().to!string();

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

public alias symlink  = createSymlink;
public alias readLink = readSymlink;
