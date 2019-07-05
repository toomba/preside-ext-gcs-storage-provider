component {

	public void function configure( required struct config ) {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		_setupStorageProvider( settings );
		_setupDefaultStorageProviderSettings( settings );
		_setupInterceptors( conf );
	}

// private helpers
	private void function _setupStorageProvider( settings ) {
		settings.storageProviders.gcs = { class = "gcsStorageProvider.services.GCSStorageProvider" };
	}

	private void function _setupDefaultStorageProviderSettings( settings ) {
		settings.gcsStorageProvider = settings.gcsStorageProvider ?: {};

		settings.gcsStorageProvider.append( {
			  accessKey = settings.injectedConfig.GCS_ASSETS_ACCESS_KEY ?: ""
			, secretKey = settings.injectedConfig.GCS_ASSETS_SECRET_KEY ?: ""
			, region    = settings.injectedConfig.GCS_ASSETS_REGION     ?: "eu"
			, bucket    = settings.injectedConfig.GCS_ASSETS_BUCKET     ?: ""
			, subpath   = settings.injectedConfig.GCS_ASSETS_SUBPATH    ?: ""
			, rootUrl   = settings.injectedConfig.GCS_ASSETS_URL        ?: "https://storage.googleapis.com"
		}, false );
	}

	private void function _setupInterceptors( conf ) {
		conf.interceptors.append( {
			  class      = "app.extensions.preside-ext-gcs-storage-provider.interceptors.GCSStorageProviderInterceptors"
			, properties = {}
		});
	}
}
