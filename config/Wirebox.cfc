component {


	public void function configure( binder ) {
		var gcsStorageSettings = binder.getColdbox().getSetting( "gcsStorageProvider" );

		gcsStorageSettings.bucket    = gcsStorageSettings.bucket    ?: ""
		gcsStorageSettings.accessKey = gcsStorageSettings.accessKey ?: ""
		gcsStorageSettings.secretKey = gcsStorageSettings.secretKey ?: ""
		gcsStorageSettings.region    = gcsStorageSettings.region    ?: "eu"
		gcsStorageSettings.subpath   = gcsStorageSettings.subpath   ?: ""
		gcsStorageSettings.rootUrl   = gcsStorageSettings.rootUrl   ?: "https://storage.googleapis.com";

		if ( Len( gcsStorageSettings.accessKey ?: "" ) && Len( gcsStorageSettings.secretKey ?: "" ) && Len( gcsStorageSettings.bucket ?: "" ) ) {
			binder.map( "assetStorageProvider" ).asSingleton().to( "gcsStorageProvider.services.GCSStorageProvider" ).noAutoWire().initWith(
				  gcsbucket    = gcsStorageSettings.bucket
				, gcsaccessKey = gcsStorageSettings.accessKey
				, gcssecretKey = gcsStorageSettings.secretKey
				, gcsregion    = gcsStorageSettings.region
				, gcsrootUrl   = gcsStorageSettings.rootUrl
				, gcssubpath   = gcsStorageSettings.subpath
			);
		}

	}

}