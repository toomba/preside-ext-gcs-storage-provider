component {


	public void function configure( binder ) {
		var s3StorageSettings = binder.getColdbox().getSetting( "s3StorageProvider" );

		s3StorageSettings.bucket    = s3StorageSettings.bucket    ?: ""
		s3StorageSettings.accessKey = s3StorageSettings.accessKey ?: ""
		s3StorageSettings.secretKey = s3StorageSettings.secretKey ?: ""
		s3StorageSettings.region    = s3StorageSettings.region    ?: "eu"
		s3StorageSettings.subpath   = s3StorageSettings.subpath   ?: ""
		s3StorageSettings.rootUrl   = s3StorageSettings.rootUrl   ?: "https://storage.googleapis.com";

		if ( Len( s3StorageSettings.accessKey ?: "" ) && Len( s3StorageSettings.secretKey ?: "" ) && Len( s3StorageSettings.bucket ?: "" ) ) {
			binder.map( "assetStorageProvider" ).asSingleton().to( "s3StorageProvider.services.S3StorageProvider" ).noAutoWire().initWith(
				  s3bucket    = s3StorageSettings.bucket
				, s3accessKey = s3StorageSettings.accessKey
				, s3secretKey = s3StorageSettings.secretKey
				, s3region    = s3StorageSettings.region
				, s3rootUrl   = s3StorageSettings.rootUrl
				, s3subpath   = s3StorageSettings.subpath
			);
		}

	}

}