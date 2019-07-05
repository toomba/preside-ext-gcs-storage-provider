component extends="coldbox.system.Interceptor" {

// PUBLIC
	public void function configure() {}

	public void function afterConfigurationLoad( event, interceptData ) {
		_setupS3Cache();
	}

// HELPERS
	private void function _setupS3Cache() {
		var cachebox       = getController().getCachebox();
		var existingCaches = cachebox.getCacheNames();

		if ( !ArrayFindNoCase( existingCaches, "s3StorageProviderCache" ) ) {
			var cache = new preside.system.coldboxModifications.cachebox.CacheProvider();

			cache.setName( "s3StorageProviderCache" );
			cache.setConfiguration({
				  objectDefaultTimeout           = 120
				, objectDefaultLastAccessTimeout = 0
				, useLastAccessTimeouts          = false
				, reapFrequency                  = 60
				, freeMemoryPercentageThreshold  = 0
				, evictionPolicy                 = "LFU"
				, evictCount                     = 200
				, maxObjects                     = 500
				, objectStore                    = "DiskStore"
				, directoryPath                  = GetTempDirectory() & "/.s3Cache"
				, autoExpandPath                 = false
			});
			cachebox.addCache( cache );
		}
	}
}