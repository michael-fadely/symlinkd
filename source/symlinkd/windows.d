module symlinkd.windows;

version (Windows):

import core.sys.windows.windows;

extern (Windows) nothrow @nogc
{
	enum
	{
		/// The link target is a directory.
		SYMBOLIC_LINK_FLAG_DIRECTORY = 0x1,
		/**
		 * Specify this flag to allow creation of symbolic links when the process is not elevated.
		 * Developer Mode must first be enabled on the machine before this option will function.
		 */
		SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE = 0x2
	}

	/**
		Creates a symbolic link.

		Params:
			lpSymlinkFileName =
				The symbolic link to be created.

				This parameter may include the path. In the ANSI version of this function, the name
				is limited to `MAX_PATH` characters. To extend this limit to 32,767 wide characters,
				call the Unicode version of the function and prepend "\\?\" to the path.

			lpTargetFileName =
				The name of the target for the symbolic link to be created.

				If `lpTargetFileName` has a device name associated with it, the link is treated as an
				absolute link; otherwise, the link is treated as a relative link.

				This parameter may include the path. In the ANSI version of this function, the name is
				limited to `MAX_PATH` characters. To extend this limit to 32,767 wide characters,
				call the Unicode version of the function and prepend "\\?\" to the path.

			dwFlags =
				Indicates whether the link target, `lpTargetFileName`, is a directory.

				`0x0`                                          - The link target is a file.
				`SYMBOLIC_LINK_FLAG_DIRECTORY`                 - The link target is a directory.
				`SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE` - Specify this flag to allow creation of symbolic links when the process is not elevated.
				                                                 Developer Mode must first be enabled on the machine before this option will function.

		Returns:
			If the function succeeds, the return value is nonzero.
			If the function fails, the return value is zero. To get extended error information, call GetLastError.
	*/
	BOOLEAN CreateSymbolicLinkA(LPCSTR  lpSymlinkFileName, LPCSTR  lpTargetFileName, DWORD dwFlags);
	/// ditto
	BOOLEAN CreateSymbolicLinkW(LPCWSTR lpSymlinkFileName, LPCWSTR lpTargetFileName, DWORD dwFlags);

	version (Unicode)
	{
		alias CreateSymbolicLink = CreateSymbolicLinkW;
	}
	else
	{
		alias CreateSymbolicLink = CreateSymbolicLinkA;
	}

	enum
	{
		/// Return the normalized drive name. This is the default.
		FILE_NAME_NORMALIZED = 0x0,
		/// Return the opened file name (not normalized).
		FILE_NAME_OPENED     = 0x8
	}

	enum
	{
		/// Return the path with the drive letter. This is the default.
		VOLUME_NAME_DOS  = 0x0,
		/// Return the path with a volume GUID path instead of the drive name.
		VOLUME_NAME_GUID = 0x1,
		/// Return the path with no drive information.
		VOLUME_NAME_NONE = 0x4,
		/// Return the path with the volume device path.
		VOLUME_NAME_NT   = 0x2
	}

	/**
		Retrieves the final path for the specified file.

		Params:
			hFile = A handle to a file or directory.
			
			lpszFilePath = A pointer to a buffer that receives the path of `hFile`.

			cchFilePath = The size of `lpszFilePath`, in `TCHAR`s. This value does not include a `NULL` termination character.

			dwFlags = The type of result to return. This parameter can be one of the following values.

			          `FILE_NAME_NORMALIZED` - Return the normalized drive name. This is the default.
			          `FILE_NAME_OPENED`     - Return the opened file name (not normalized).

			          This parameter can also include one of the following values.

			          `VOLUME_NAME_DOS`  - Return the path with the drive letter. This is the default.
			          `VOLUME_NAME_GUID` - Return the path with a volume GUID path instead of the drive name.
			          `VOLUME_NAME_NONE` - Return the path with no drive information.
			          `VOLUME_NAME_NT`   - Return the path with the volume device path.

		Returns:
			If the function succeeds, the return value is the length of the string received by `lpszFilePath`, in `TCHAR`s.
			This value does not include the size of the terminating null character.

			Windows Server 2008 and Windows Vista: For the ANSI version of this function, `GetFinalPathNameByHandleA`, the
			return value includes the size of the terminating null character.

			If the function fails because `lpszFilePath` is too small to hold the string plus the terminating null character,
			the return value is the required buffer size, in `TCHAR`s. This value includes the size of the terminating null character.

			If the function fails for any other reason, the return value is zero. To get extended error information, call `GetLastError`.


			`ERROR_PATH_NOT_FOUND`   - Can be returned if you are searching for a drive letter and one does not exist.
			                           For example, the handle was opened on a drive that is not currently mounted, or
			                           if you create a volume and do not assign it a drive letter. If a volume has no
			                           drive letter, you can use the volume GUID path to identify it.
			                           
			                           This return value can also be returned if you are searching for a volume GUID
			                           path on a network share. Volume GUID paths are not created for network shares.

			`ERROR_NOT_ENOUGH_MEMORY` - Insufficient memory to complete the operation.

			`ERROR_INVALID_PARAMETER` - Invalid flags were specified for `dwFlags`. 
	*/
	uint GetFinalPathNameByHandleA(HANDLE hFile, LPSTR  lpszFilePath, uint cchFilePath, uint dwFlags);
	/// ditto
	uint GetFinalPathNameByHandleW(HANDLE hFile, LPWSTR lpszFilePath, uint cchFilePath, uint dwFlags);

	version (Unicode)
	{
		alias GetFinalPathNameByHandle = GetFinalPathNameByHandleW;
	}
	else
	{
		alias GetFinalPathNameByHandle = GetFinalPathNameByHandleA;
	}
}
