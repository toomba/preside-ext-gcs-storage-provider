# Preside GCS Storage Provider

The GCS Storage Provider for Preside provides the best way to integrate GCS with your Preside applications. While you can use native Lucee GCS mappings, this method has the following advantages:

* More intuitive to configure
* Public/Private asset uploads are taken care of with precise ACL setting
* Local file cache configurable with Cachebox

The provider is pretty much feature complete, but should be considered BETA at the time of this writing.

## Installation

```box install preside-ext-gcs-storage-provider```

## Configuration

### Using as your default storage provider for the asset manager

To configure the provider for use throughout the asset manager, you will need to set your S3 credentials and bucket name (at a minimum). These can either be set directly in your Config.cfc (not recommended), or injected using environment variables. The settings are:

```cfc
settings.s3StorageProvider = {
	  accessKey = "" // required, i.e. your S3 access key
	, secretKey = "" // required, i.e. your S3 secret access key
	, bucket    = "" // required, e.g. 'my-unique-s3-bucket'
	, region    = "" // optional, e.g. eu (default is eu)
	, subpath   = "" // optional, e.g. /sub/path/in/bucket
	, rootUrl   = "" // optional, e.g. https://storage.googleapis.com"
};
```

These can be injected using the following environment variables (e.g. if deploying with docker):

```
PRESIDE_S3_ASSETS_ACCESS_KEY
PRESIDE_S3_ASSETS_SECRET_KEY
PRESIDE_S3_ASSETS_REGION
PRESIDE_S3_ASSETS_BUCKET
PRESIDE_S3_ASSETS_SUBPATH
PRESIDE_S3_ASSETS_URL
```

## Caching

The extension setups up a cachebox cache named, `s3StorageProviderCache`, to cache binary file downloads from S3. The default is a `DiskCache` in the temp directory with a `2 hour` timeout and max `500` objects. If you wish to override this, simply configure your own `s3StorageProviderCache` in your application's `Cachebox.cfc`. For reference, here are the settings we have used:

```cfc
{
	  objectStore                    = "DiskStore"
	, objectDefaultTimeout           = 120
	, objectDefaultLastAccessTimeout = 0
	, useLastAccessTimeouts          = false
	, reapFrequency                  = 60
	, freeMemoryPercentageThreshold  = 0
	, evictionPolicy                 = "LFU"
	, evictCount                     = 200
	, maxObjects                     = 500
	, directoryPath                  = GetTempDirectory() & "/.s3Cache"
	, autoExpandPath                 = false
}
```

## Using for non-asset-manager storage

If you have configured storage providers that are for use outside of the asset manager ([see documentation](https://docs.preside.org/devguides/assetmanager.html#overriding-the-default-storage-location)), you can change them to use the S3 Storage Provider in your application's `/config/Wirebox.cfc`. For example:

```cfc
component extends="preside.system.config.WireBox" {

	public void function configure() {
		super.configure();

		map( "myCustomStorageProvider" ).asSingleton().to( "s3StorageProvider.services.S3StorageProvider" ).noAutoWire().initWith(
			  s3bucket    = "" // your settings here
			, s3accessKey = "" // your settings here
			, s3secretKey = "" // your settings here
			, s3region    = "" // your settings here
			, s3rootUrl   = "" // your settings here
			, s3subpath   = "" // your settings here
		);
	}

}

```

# Contributing

Contribution in all forms is very welcome. Use Github to create pull requests for tests, logic, features and documentation. Or, get in touch over at Preside's slack team and we'll be happy to help and chat: [https://presidecms-slack.herokuapp.com/](https://presidecms-slack.herokuapp.com/).