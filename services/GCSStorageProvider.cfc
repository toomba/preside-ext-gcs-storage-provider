/**
 * Implementation of the [[api-storageprovider]] interface to provide an S3 based
 * storage provider.
 *
 * @singleton
 * @autodoc
 *
 */
component implements="preside.system.services.fileStorage.StorageProvider" displayname="File System Storage Provider" {

// CONSTRUCTOR
	public any function init(
		  required string gcsbucket
		, required string gcsaccessKey
		, required string gcssecretKey
		,          string gcsregion          = "eu"
		,          string gcsrootUrl         = "https://storage.googleapis.com"
		,          string gcssubpath         = ""
		,          string gcspublicRootPath  = "/public"
		,          string gcsprivateRootPath = "/private"
		,          string gcstrashRootPath   = "/.trash"
	){
		_setRegion( arguments.gcsregion );
		_setBucket( arguments.gcsbucket );
		_setPublicDirectory( arguments.gcssubpath & arguments.gcspublicRootPath );
		_setPrivateDirectory( arguments.gcssubpath & arguments.gcsprivateRootPath );
		_setTrashDirectory( arguments.gcssubpath & arguments.gcstrashRootPath );
		_setRootUrl( arguments.gcsrootUrl );

		_setupS3Service( arguments.gcsaccessKey, arguments.gcssecretKey, arguments.gcsregion );

		return this;
	}

// PUBLIC API METHODS
	public any function validate( required struct configuration, required any validationResult ) {
		var bucket    = arguments.configuration.bucket    ?: "";
		var s3Service = "";

		try {
			s3Service = _instantiateS3Service(
				  accessKey = arguments.configuration.accessKey ?: ""
				, secretKey = arguments.configuration.secretKey ?: ""
				, region    = arguments.configuration.region    ?: "us-west-1"
			);
			s3Service.listAllBuckets();
		} catch( any e ) {
			validationResult.addError( "s3accessKey", "storage-providers.s3:validation.connection.error", [ e.s3ErrorMessage ?: e.message ] );
			return;
		}

		try {
			s3Service.listObjects( arguments.configuration.bucket ?: "" );
		} catch( any e ) {
			validationResult.addError( "s3bucket", "storage-providers.s3:validation.bucket.not.exists", [ arguments.configuration.bucket ?: "", e.s3ErrorMessage ?: e.message ] );
			return;
		}
	}


	public query function listObjects( required string path, boolean private=false ){
		var objects = QueryNew( "name,path,size,lastmodified" );
		var prefix  = _expandPath( argumentCollection=arguments );

		var s3Objects = _getS3Service().listObjects(
			  _getBucket() // bucketname
			, prefix       // prefix
			, "/"          // delimiter
			, 0            // max results
		);

		for( var s3Object in s3Objects ) {
			var fullPath = s3Object.getName();
			var dir      = "/" & ListDeleteAt( fullPath, ListLen( fullPath, "/" ), "/" );
			var fileName = ListLast( s3Object.getName(), "/" );
			var size     = s3Object.getContentLength();
			var modified = s3Object.getLastModifiedDate();

			if ( size ) {
				QueryAddRow( objects, [ fileName, dir, size, modified ] );
			}
		}

		return objects;
	}


	public struct function getObjectInfo( required string path, boolean trashed=false, boolean private=false ){
		try {
			var objects  =  listObjects( argumentCollection=arguments );
			var fullpath = "/" & _expandPath( argumentCollection=arguments );
			for( object in objects ) {
				if ( fullPath == "#object.path#/#object.name#" ) {
					return {
						  size         = object.size         ?: ""
						, lastmodified = object.lastmodified ?: ""
					};
				}
			}
		} catch( any e ) {}
		return {};
	}

	public boolean function objectExists( required string path, boolean trashed=false, boolean private=false ){
		return getObjectInfo( argumentCollection=arguments ).count() > 0;
	}

	public binary function getObject( required string path, boolean trashed=false, boolean private=false ){
		var cacheKey = _getCacheKey( argumentCollection=arguments );
		var fromCache = _getFromCache( cacheKey );

		if ( !IsNull( local.fromCache ) ) {
			return fromCache;
		}

		try {
			var s3Object     = _getS3Service().getObject( _getBucket(), _expandPath( argumentCollection=arguments ) );
			var binaryObject = _getS3Utils().readInputStreamToBytes( s3Object.getDataInputStream() );
			var verified     = s3Object.verifyData( binaryObject );

		} catch ( any e ) {
			throw(
				  type    = "storageProvider.objectNotFound"
				, message = "The object, [#arguments.path#], could not be found or is not accessible"
			);
		}

		if ( !verified ) {
			throw(
				  type    = "storageProvider.objectNotFound"
				, message = "The object, [#arguments.path#], could not be found or is not accessible. Downloaded from S3 but failed validation. Please try again."
			);
		}

		_setToCache( cacheKey, binaryObject );

		return binaryObject;
	}

	public void function putObject( required any object, required string path, boolean private=false ){
		var s3Object = CreateObject( "java", "org.jets3t.service.model.S3Object" ).init( _expandPath( argumentCollection=arguments ), arguments.object );
		var dispositionAndMimeType = _getDispositionAndMimeType( ListLast( arguments.path, "." ) );

		s3Object.setAcl( _getAcl( argumentCollection=arguments ) );
		s3Object.setStorageClass( _getStorageClass( argumentCollection=arguments, s3Object=s3Object ) );

		if ( StructCount( dispositionAndMimeType ) ) {
			if ( dispositionAndMimeType.disposition == "attachment" ) {
				s3Object.setContentDisposition( dispositionAndMimeType.disposition & "; filename=""#ListLast( arguments.path, "\/" )#""" );
			}
			s3Object.setContentType( dispositionAndMimeType.mimeType );
		}

		try{
			_getS3Service().putObject( _getBucket(), s3Object );
		}catch(any e){
			var _skipError = false;
			if(structKeyExists(e, "ErrorCode") && structKeyExists(e, "ErrorMessage")){
				//SKIP GOOGLE SPECIFIC ERROR
				if(e.ErrorCode == "InvalidArgument" && e.ErrorMessage == "Invalid argument. Invalid owner Google Storage Id"){
					_skipError = true;
				}
			}
			if(!_skipError){
				throw(e);
			}
		}

		var cacheKey = _getCacheKey( argumentCollection=arguments );
		_setToCache( cacheKey, arguments.object );

	}

	public void function deleteObject( required string path, boolean trashed=false, boolean private=false ){
		_getS3Service().deleteObject( _getBucket(), _expandPath( argumentCollection=arguments ) );
		_clearFromCache( _getCacheKey( argumentCollection=arguments ) );
	}

	public string function softDeleteObject( required string path, boolean private=false ){
		var originalPath = _expandPath( argumentCollection=arguments );
		var newPath      = _expandPath( argumentCollection=arguments, trashed=true );

		var newS3Object = CreateObject( "java", "org.jets3t.service.model.S3Object" ).init( newPath );

		newS3Object.setAcl( _getAcl( argumentCollection=arguments, trashed=true ) );
		newS3Object.setStorageClass( _getStorageClass( argumentCollection=arguments, s3Object=newS3Object, trashed=true ) );


		try{
			_getS3Service().moveObject( _getBucket(), originalPath, _getBucket(), newS3Object, true );
		}catch(any e){
			var _skipError = false;
			if(structKeyExists(e, "ErrorCode") && structKeyExists(e, "ErrorMessage")){
				//SKIP GOOGLE SPECIFIC ERROR
				if(e.ErrorCode == "InvalidArgument" && e.ErrorMessage == "Invalid argument. Invalid owner Google Storage Id"){
					_skipError = true;
				}
			}
			if(!_skipError){
				throw(e);
			}
		}
		_clearFromCache( _getCacheKey( argumentCollection=arguments ) );

		return arguments.path;
	}

	public boolean function restoreObject( required string trashedPath, required string newPath, boolean private=false ){
		var originalPath = _expandPath( argumentCollection=arguments, path=arguments.trashedPath, trashed=true );
		var newPath      = _expandPath( argumentCollection=arguments, path=arguments.newPath    , trashed=false );

		var newS3Object = CreateObject( "java", "org.jets3t.service.model.S3Object" ).init( newPath );
		newS3Object.setAcl( _getAcl( argumentCollection=arguments, trashed=false ) );
		newS3Object.setStorageClass( _getStorageClass( argumentCollection=arguments, s3Object=newS3Object, trashed=false ) );

		_getS3Service().moveObject( _getBucket(), originalPath, _getBucket(), newS3Object, true );

		return true;
	}

	public void function moveObject( required string originalPath, required string newPath, boolean originalIsPrivate=false, boolean newIsPrivate=false ) {
		var originalPath = _expandPath( path=arguments.originalPath, private=originalIsPrivate );
		var newPath      = _expandPath( path=arguments.newPath, private=newIsPrivate );

		var newS3Object = CreateObject( "java", "org.jets3t.service.model.S3Object" ).init( newPath );
		newS3Object.setAcl( _getAcl( private=arguments.newIsPrivate ) );
		newS3Object.setStorageClass( _getStorageClass( private=arguments.newIsPrivate, s3Object=newS3Object ) );

		_getS3Service().moveObject( _getBucket(), originalPath, _getBucket(), newS3Object, true );
		_clearFromCache( _getCacheKey( path=arguments.originalPath, private=originalIsPrivate ) );
	}

	public string function getObjectUrl( required string path ){
		var rootUrl = _getRootUrl();

		if ( Trim( rootUrl ).len() ) {
			return rootUrl & _getBucket() & "/" & _expandPath( arguments.path );
		}

		return "";
	}

// PRIVATE HELPERS
	private void function _setupS3Service(
		  required string accessKey
		, required string secretKey
		, required string region
	) {
		_setS3Service( _instantiateS3Service( argumentCollection=arguments ) );
		_setS3Utils( CreateObject( "java", "org.jets3t.service.utils.ServiceUtils" ) );
		_setReadPermission(  CreateObject( "java", "org.jets3t.service.acl.Permission" ).PERMISSION_READ );
		_setPublicGroup(  CreateObject( "java", "org.jets3t.service.acl.GroupGrantee" ).ALL_USERS );
	}

	private string function _expandPath( required string path, boolean trashed=false, boolean private=false ){
		var relativePath = _cleanPath( arguments.path, arguments.trashed, arguments.private );
		var rootPath     = arguments.trashed ? _getTrashDirectory() : ( arguments.private ? _getPrivateDirectory() : _getPublicDirectory() );

		return ReReplace( rootPath & relativePath, "^/", "" );
	}

	private string function _cleanPath( required string path, boolean trashed=false, boolean private=false ){
		var cleaned = ListChangeDelims( arguments.path, "/", "\" );

		cleaned = ReReplace( cleaned, "^/", "" );
		cleaned = Trim( cleaned );
		if ( !arguments.trashed ) {
			cleaned = LCase( cleaned );
		}

		return cleaned;
	}

	private void function _ensureDirectoryExists( required string dir ){
		if ( arguments.dir.len() && !DirectoryExists( arguments.dir ) ) {
			try {
				DirectoryCreate( arguments.dir, true, true );
			} catch( any e ) {
				if ( !DirectoryExists( arguments.dir ) ) {
					rethrow;
				}
			}
		}
	}

	private any function _instantiateS3Service(
		  required string accessKey
		, required string secretKey
		, required string region
	) {
		var credentials = CreateObject( "java", "org.jets3t.service.security.AWSCredentials" ).init( arguments.accessKey, arguments.secretKey );
		var props       = CreateObject( "java", "org.jets3t.service.Jets3tProperties" ).init();

		props.setProperty( "s3service.s3-endpoint", "storage.googleapis.com" );

		return CreateObject( "java", "org.jets3t.service.impl.rest.httpclient.RestS3Service" ).init( credentials, NullValue(), NullValue(), props );
	}

	private any function _getAcl( required boolean private, boolean trashed=false ) {
		var acl = _getS3Service().getBucketAcl( _getBucketObject() );

		if ( arguments.private || arguments.trashed ) {
			acl.revokeAllPermissions( _getPublicGroup() );
		} else {
			acl.grantPermission( _getPublicGroup(), _getReadPermission() );
		}

		return acl;
	}

	private any function _getStorageClass( required any s3Object, required boolean private, boolean trashed=false ) {
		// TODO, make this configurable

		if ( arguments.trashed ) {
			return s3Object.STORAGE_CLASS_REDUCED_REDUNDANCY;
		}

		return s3Object.STORAGE_CLASS_STANDARD;
	}

	private any function _getCache() {
		if ( !StructKeyExists( variables, "_cache" ) ) {
			if ( StructKeyExists( application, "cbBootstrap" ) && IsDefined( 'application.cbBootstrap.getController' ) ) {
				variables._cache = application.cbBootstrap.getController().getCachebox().getCache( "gcsStorageProviderCache" );
			}
		}

		return variables._cache ?: NullValue();
	}

	private string function _getCacheKey( required string path, boolean private=false, boolean trashed=false ) {
		return _getBucket() & "#arguments.path#.#arguments.private#.#arguments.trashed#";
	}

	private any function _getFromCache() {
		var cache = _getCache();
		if ( !IsNull( local.cache ) ) {
			return cache.get( argumentCollection=arguments );
		}
	}

	private any function _setToCache() {
		var cache = _getCache();

		if ( !IsNull( local.cache ) ) {
			return cache.set( argumentCollection=arguments );
		}
	}

	private any function _clearFromCache() {
		var cache = _getCache();

		if ( !IsNull( local.cache ) ) {
			return cache.clearQuiet( argumentCollection=arguments );
		}

	}

	private struct function _getDispositionAndMimeType( required string fileExtension ) {
		if ( !StructKeyExists( variables, "_extensionMappings" )  ) {
			variables._extensionMappings = {};
			if ( StructKeyExists( application, "cbBootstrap" ) && IsDefined( 'application.cbBootstrap.getController' ) ) {
				var typeSettings = application.cbBootstrap.getController().getSetting( "assetmanager.types" );

				for( var group in typeSettings ) {
					for( var ext in typeSettings[ group ] ) {
						var mimeType = typeSettings[ group ][ ext ].mimeType ?: "";
						var serveAsAttachment = IsBoolean( typeSettings[ group ][ ext ].serveAsAttachment ?: "" ) && typeSettings[ group ][ ext ].serveAsAttachment;
						if ( Len( Trim( mimeType ) ) ) {
							variables._extensionMappings[ ext ] = {
								  mimeType = mimeType
								, disposition = serveAsAttachment ? "attachment" : "inline"
							};
						}
					}
				}
			}
		}

		return variables._extensionMappings[ arguments.fileExtension ] ?: {};
	}


// GETTERS AND SETTERS
	private string function _getBucket() {
		return _bucket;
	}
	private void function _setBucket( required string bucket ) {
		_bucket = arguments.bucket;
		_setBucketObject( CreateObject( "java", "org.jets3t.service.model.S3Bucket" ).init( _bucket ) );
	}

	private any function _getBucketObject() {
		return _bucketObject;
	}
	private void function _setBucketObject( required any bucketObject ) {
		_bucketObject = arguments.bucketObject;
	}

	private string function _getRegion() {
		return _region;
	}
	private void function _setRegion( required string region ) {
		_region = arguments.region;
	}

	private string function _getPublicDirectory() {
		return _publicDirectory;
	}
	private void function _setPublicDirectory( required string publicDirectory ) {
		_publicDirectory = arguments.publicDirectory;
		if ( Len( Trim( _publicDirectory ) ) && Right( _publicDirectory, 1 ) != "/" ) {
			_publicDirectory &= "/";
		}
	}

	private any function _getPrivateDirectory() {
		return _privateDirectory;
	}
	private void function _setPrivateDirectory( required any privateDirectory ) {
		_privateDirectory = arguments.privateDirectory;
		if ( Len( Trim( _privateDirectory ) ) && Right( _privateDirectory, 1 ) != "/" ) {
			_privateDirectory &= "/";
		}
	}

	private string function _getTrashDirectory(){
		return _trashDirectory;
	}
	private void function _setTrashDirectory( required string trashDirectory ){
		_trashDirectory = arguments.trashDirectory;
		if ( Len( Trim( _trashDirectory ) ) && Right( _trashDirectory, 1 ) != "/" ) {
			_trashDirectory &= "/";
		}
	}

	private string function _getRootUrl(){
		return _rootUrl;
	}
	private void function _setRootUrl( required string rootUrl ){
		_rootUrl = arguments.rootUrl;

		if ( Len( Trim( _rootUrl ) ) && Right( _rootUrl, 1 ) != "/" ) {
			_rootUrl &= "/";
		}
	}

	private any function _getS3Service() {
		return _s3Service;
	}
	private void function _setS3Service( required any s3Service ) {
		_s3Service = arguments.s3Service;
	}

	private any function _getS3Utils() {
		return _s3Utils;
	}
	private void function _setS3Utils( required any s3Utils ) {
		_s3Utils = arguments.s3Utils;
	}

	private any function _getReadPermission() {
		return _readPermission;
	}
	private void function _setReadPermission( required any readPermission ) {
		_readPermission = arguments.readPermission;
	}

	private any function _getPublicGroup() {
		return _publicGroup;
	}
	private void function _setPublicGroup( required any publicGroup ) {
		_publicGroup = arguments.publicGroup;
	}
}
