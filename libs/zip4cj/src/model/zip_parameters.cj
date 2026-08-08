/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

/*
 * Encapsulates the parameters that that control how Zip4J encodes data
 */
public class ZipParameters {
    private var compressionMethod: CompressionMethod = CompressionMethod.DEFLATE

    private var compressionLevel: CompressionLevel = CompressionLevel.NORMAL

    private var encryptFiles: Bool = false

    private var encryptionMethod: EncryptionMethod = EncryptionMethod.NONE

    private var readHiddenFiles: Bool = true

    private var readHiddenFolders: Bool = true

    private var aesKeyStrength: AesKeyStrength = AesKeyStrength.KEY_STRENGTH_256

    private var aesVersion: AesVersion = AesVersion.TWO

    private var includeRootFolder: Bool = true

    private var entryCRC: Int64 = 0

    private var defaultFolderPath: ?String = None

    private var fileNameInZip: ?String = None

    private var lastModifiedFileTime: Int64 = 0

    private var entrySize: Int64 = -1

    private var writeExtendedLocalFileHeader: Bool = true

    private var overrideExistingFilesInZip: Bool = true

    private var rootFolderNameInZip: ?String = None

    private var fileComment: ?String = None

    private var symbolicLinkAction: SymbolicLinkAction = SymbolicLinkAction.INCLUDE_LINKED_FILE_ONLY

    private var excludeFileFilter: ?ExcludeFileFilter = None

    private var unixMode: Bool = false

    /*
     * Create a ZipParameters instance with default values
     * CompressionMethod.DEFLATE, CompressionLevel.NORMAL, EncryptionMethod.NONE,
     * AesKeyStrength.KEY_STRENGTH_256, AesVerson.Two, SymbolicLinkAction.INCLUDE_LINKED_FILE_ONLY,
     * readHiddenFiles is true, readHiddenFolders is true, includeRootInFolder is true,
     * writeExtendedLocalFileHeader is true, overrideExistingFilesInZip is true
     */
    public init() {}

    /*
     * Create a clone of given ZipParameters instance
     *
     * @param zipParms the ZipParameters instance to clone
     */
    public init(zipParms: ZipParameters) {
        this.compressionMethod = zipParms.getCompressionMethod()
        this.compressionLevel = zipParms.getCompressionLevel()
        this.encryptFiles = zipParms.isEncryptFiles()
        this.encryptionMethod = zipParms.getEncryptionMethod()
        this.readHiddenFiles = zipParms.isReadHiddenFiles()
        this.readHiddenFolders = zipParms.isReadHiddenFolders()
        this.aesKeyStrength = zipParms.getAesKeyStrength()
        this.aesVersion = zipParms.getAesVersion()
        this.includeRootFolder = zipParms.isIncludeRootFolder()
        this.entryCRC = zipParms.getEntryCRC()
        this.defaultFolderPath = zipParms.getDefaultFolderPath()
        this.fileNameInZip = zipParms.getFileNameInZip()
        this.lastModifiedFileTime = zipParms.getLastModifiedFileTime()
        this.entrySize = zipParms.getEntrySize()
        this.writeExtendedLocalFileHeader = zipParms.isWriteExtendedLocalFileHeader()
        this.overrideExistingFilesInZip = zipParms.isOverrideExistingFilesInZip()
        this.rootFolderNameInZip = zipParms.getRootFolderNameInZip()
        this.fileComment = zipParms.getFileComment()
        this.symbolicLinkAction = zipParms.getSymbolicLinkAction()
        this.excludeFileFilter = zipParms.getExcludeFileFilter()
        this.unixMode = zipParms.isUnixMode()
    }

    /*
     * Get the compression method specified in this ZipParameters
     *
     * @return the ZIP compression method
     */
    public func getCompressionMethod(): CompressionMethod {
        return compressionMethod
    }

    /*
     * Set the ZIP compression method
     * @param compressionMethod the ZIP compression method
     */
    public func setCompressionMethod(compressionMethod: CompressionMethod) {
        this.compressionMethod = compressionMethod
    }

    /*
     * Test if files files are to be encrypted
     *
     * @return true if files are to be encrypted
     */
    public func isEncryptFiles(): Bool {
        return encryptFiles
    }

    /*
     * Set the flag indicating that files are to be encrypted
     *
     * @param encryptFiles if true, files will be encrypted
     */
    public func setEncryptFiles(encryptFiles: Bool) {
        this.encryptFiles = encryptFiles
    }

    /*
     * Get the encryption method used to encrypt files
     *
     * @return the encryption method
     */
    public func getEncryptionMethod(): EncryptionMethod {
        return encryptionMethod
    }

    /*
     * Set the encryption method used to encrypt files
     *
     * @param encryptionMethod the encryption method to be used
     */
    public func setEncryptionMethod(encryptionMethod: EncryptionMethod) {
        this.encryptionMethod = encryptionMethod
    }

    /*
     * Get the compression level used to compress files
     *
     * @return the compression level used to compress files
     */
    public func getCompressionLevel(): CompressionLevel {
        return compressionLevel
    }

    /*
     * Set the compression level used to compress files
     *
     * @param compressionLevel the compression level used to compress files
     */
    public func setCompressionLevel(compressionLevel: CompressionLevel) {
        this.compressionLevel = compressionLevel
    }

    /*
     * Test if hidden files will be included during folder recursion
     *
     * @return true if hidden files will be included when adding folders to the zip
     */
    public func isReadHiddenFiles(): Bool {
        return readHiddenFiles
    }

    /*
     * Indicate if hidden files will be included during folder recursion
     *
     * @param readHiddenFiles if true, hidden files will be included when adding folders to the zip
     */
    public func setReadHiddenFiles(readHiddenFiles: Bool) {
        this.readHiddenFiles = readHiddenFiles
    }

    /*
     * Test if hidden folders will be included during folder recursion
     *
     * @return true if hidden folders will be included when adding folders to the zip
     */
    public func isReadHiddenFolders(): Bool {
        return readHiddenFolders
    }

    /*
     * Indicate if hidden folders will be included during folder recursion
     *
     * @param readHiddenFolders if true, hidden folders will be included when added folders to the zip
     */
    public func setReadHiddenFolders(readHiddenFolders: Bool) {
        this.readHiddenFolders = readHiddenFolders
    }

    /*
     * Get the key strength of the AES encryption key
     *
     * @return the key strength of the AES encryption key
     */
    public func getAesKeyStrength(): AesKeyStrength {
        return aesKeyStrength
    }

    /*
     * Set the key strength of the AES encryption key
     *
     * @param aesKeyStrength the key strength of the AES encryption key
     */
    public func setAesKeyStrength(aesKeyStrength: AesKeyStrength) {
        this.aesKeyStrength = aesKeyStrength
    }

    /*
     * Get the AES format version used for encryption
     *
     * @return the AES format version used for encryption
     */
    public func getAesVersion(): AesVersion {
        return aesVersion
    }

    /*
     * Set the AES format version to use for encryption
     *
     * @param aesVersion the AES format version to use
     */
    public func setAesVersion(aesVersion: AesVersion) {
        this.aesVersion = aesVersion
    }

    /*
     * Test if the parent folder of the added files will be included in the ZIP
     *
     * @return true if the parent folder of the added files will be included into the zip
     */
    public func isIncludeRootFolder(): Bool {
        return includeRootFolder
    }

    /*
     * Set the flag to indicate if the parent folder of added files will be included in the ZIP
     *
     * @param includeRootFolder if true, the parent folder of added files will be included in the ZIP
     */
    public func setIncludeRootFolder(includeRootFolder: Bool) {
        this.includeRootFolder = includeRootFolder
    }

    public func getEntryCRC() {
        return entryCRC
    }

    public func setEntryCRC(entryCRC: Int64) {
        this.entryCRC = entryCRC
    }

    public func getDefaultFolderPath(): ?String {
        return defaultFolderPath
    }

    public func setDefaultFolderPath(defaultFolderPath: String) {
        this.defaultFolderPath = defaultFolderPath
    }

    public func getFileNameInZip(): ?String {
        return fileNameInZip
    }

    public func setFileNameInZip(fileNameInZip: String) {
        this.fileNameInZip = fileNameInZip
    }

    /*
     * Get the last modified time to be used for files written to the ZIP
     *
     * @return the last modified time in milliseconds since the epoch
     */
    public func getLastModifiedFileTime(): Int64 {
        return lastModifiedFileTime
    }

    /*
     * Set the last modified time recorded in the ZIP file for the added files.  If less than 0,
     * the last modified time is cleared and the current time is used
     *
     * @param lastModifiedFileTime the last modified time in milliseconds since the epoch
     */
    public func setLastModifiedFileTime(lastModifiedFileTime: Int64) {
        if (lastModifiedFileTime < 0) {
            this.lastModifiedFileTime = 0
            return
        }

        this.lastModifiedFileTime = lastModifiedFileTime
    }

    public func getEntrySize() {
        return entrySize
    }

    public func setEntrySize(entrySize: Int64) {
        this.entrySize = entrySize
    }

    public func isWriteExtendedLocalFileHeader() {
        return writeExtendedLocalFileHeader
    }

    public func setWriteExtendedLocalFileHeader(writeExtendedLocalFileHeader: Bool) {
        this.writeExtendedLocalFileHeader = writeExtendedLocalFileHeader
    }

    public func isOverrideExistingFilesInZip(): Bool {
        return overrideExistingFilesInZip
    }

    /*
     * Set the behavior if a file is added that already exists in the ZIP.
     *
     * @param overrideExistingFilesInZip if true, remove the existing file in the ZIP if false do not add the new file
     */
    public func setOverrideExistingFilesInZip(overrideExistingFilesInZip: Bool) {
        this.overrideExistingFilesInZip = overrideExistingFilesInZip
    }

    public func getRootFolderNameInZip(): ?String {
        return rootFolderNameInZip
    }

    /*
     * Set the folder name that will be prepended to the filename in the ZIP.  This value is ignored
     * if setFileNameInZip() is specified with a non-null, non-empty string.
     *
     * @param rootFolderNameInZip the name of the folder to be prepended to the filename in the ZIP archive
     */
    public func setRootFolderNameInZip(rootFolderNameInZip: String) {
        this.rootFolderNameInZip = rootFolderNameInZip
    }

    /*
     * Get the file comment
     *
     * @return the file comment
     */
    public func getFileComment(): ?String {
        return fileComment
    }

    /*
     * Set the file comment
     *
     * @param fileComment the file comment
     */
    public func setFileComment(fileComment: String) {
        this.fileComment = fileComment
    }

    /*
     * Get the behavior when adding a symbolic link
     *
     * @return the behavior when adding a symbolic link
     */
    public func getSymbolicLinkAction(): SymbolicLinkAction {
        return symbolicLinkAction
    }

    /*
     * Set the behavior when adding a symbolic link
     *
     * @param symbolicLinkAction the behavior when adding a symbolic link
     */
    public func setSymbolicLinkAction(symbolicLinkAction: SymbolicLinkAction) {
        this.symbolicLinkAction = symbolicLinkAction
    }

    /*
     * Returns the file exclusion filter that is currently being used when adding files/folders to zip file
     *
     * @return ExcludeFileFilter
     */
    public func getExcludeFileFilter(): ?ExcludeFileFilter {
        return excludeFileFilter
    }

    /*
     * Set a filter to exclude any files from the list of files being added to zip. Mostly used when adding a folder
     * to a zip, and if certain files have to be excluded from adding to the zip file.
     */
    public func setExcludeFileFilter(excludeFileFilter: ExcludeFileFilter) {
        this.excludeFileFilter = excludeFileFilter
    }

    /*
     * Returns true if zip4j is using unix mode as default. Returns False otherwise.
     *
     * @return true if zip4j is using unix mode as default, false otherwise
     */
    public func isUnixMode(): Bool {
        return unixMode
    }

    /*
     * When set to true, zip4j uses unix mode as default when generating file headers.
     *
     * @param unixMode
     */
    public func setUnixMode(unixMode: Bool) {
        this.unixMode = unixMode
    }
}

/*
 * Indicates the action to take when a symbolic link is added to the ZIP file
 */
public enum SymbolicLinkAction <: Equatable<SymbolicLinkAction> {
    /*
     * Add only the symbolic link itself, not the target file or its contents
     */
    | INCLUDE_LINK_ONLY
    /*
     * Add only the target file and its contents, using the filename of the symbolic link
     */
    | INCLUDE_LINKED_FILE_ONLY
    /*
     * Add the symbolic link itself and the target file with its original filename and its contents
     */
    | INCLUDE_LINK_AND_LINKED_FILE

    public operator func ==(that: SymbolicLinkAction): Bool {
        match ((this, that)) {
            case (INCLUDE_LINK_ONLY, INCLUDE_LINK_ONLY) => true
            case (INCLUDE_LINKED_FILE_ONLY, INCLUDE_LINKED_FILE_ONLY) => true
            case (INCLUDE_LINK_AND_LINKED_FILE, INCLUDE_LINK_AND_LINKED_FILE) => true
            case _ => false
        }
    }

    public operator func !=(that: SymbolicLinkAction): Bool {
        return !(this == that)
    }
}
