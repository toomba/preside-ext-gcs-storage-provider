
component extends="preside.system.services.assetManager.AssetManagerService" {

	private void function _deleteAssociatedFiles( required string assetId, required string folderId, string versionId="", boolean softDelete=false, boolean private=false ) {
		var versionFilter    = { asset = arguments.assetId };
		var derivativeFilter = { asset = arguments.assetId };
		var assetVersionDao  = _getAssetVersionDao();
		var derivativeDao    = _getDerivativeDao();
		var trashedPath      = "";

		if ( arguments.versionId.len() ) {
			versionFilter.id               = arguments.versionId;
			derivativeFilter.asset_version = arguments.versionId;
		}

		if ( arguments.softDelete ) {
			versionFilter.is_trashed = false;
			derivativeFilter.is_trashed = false;
		}

		var versions        = assetVersionDao.selectData( filter=versionFilter   , selectfields=[ "id", "storage_path" ] );
		var derivatives     = derivativeDao.selectData( filter=derivativeFilter, selectfields=[ "id", "storage_path" ] );
		var storageProvider = _getStorageProviderForFolder( arguments.folderId );

		for( var version in versions ) {
			if ( arguments.softDelete ) {
				trashedPath = storageProvider.softDeleteObject( path=version.storage_path, private=arguments.private );
				assetVersionDao.updateData( id=version.id, data={ is_trashed=true, trashed_path=trashedPath, asset_url="" } );
			} else {
				storageProvider.deleteObject( version.storage_path );
			}
		}
		for( var derivative in derivatives ) {
			if(!_isPendingAssetURL(derivative.storage_path)){
				if ( arguments.softDelete ) {
					trashedPath = storageProvider.softDeleteObject( path=derivative.storage_path, private=arguments.private );
					derivativeDao.updateData( id=derivative.id, data={ is_trashed=true, trashed_path=trashedPath, asset_url="" } );
				} else {
					storageProvider.deleteObject( derivative.storage_path );
				}
			}
		}
	}

}