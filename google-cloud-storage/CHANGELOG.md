# Release History

### 0.23.2 / 2017-02-21

* Allow setting a File's storage_class on file creation
* Allow updating an existing File's storage_class
* Add File#rotate to rotate encryption keys
* Add PostObject and Bucket#post_object for uploading via HTML forms

### 0.23.1 / 2016-12-12

* Support Google extension headers on signed URLs (calavera)

### 0.23.0 / 2016-12-8

* Remove `encryption_key_sha256` method parameter, hash will be calculated using `encryption_key`
* Many documentation improvements

### 0.21.0 / 2016-10-20

* New service constructor Google::Cloud::Storage.new
* Bucket#signed_url added to create URLs without a File object

### 0.20.2 / 2016-09-30

* Fix issue with signed_url and file names with spaces (gsbucks)

### 0.20.1 / 2016-09-02

* Fix for timeout on uploads.

### 0.20.0 / 2016-08-26

This gem contains the Google Cloud Storage service implementation for the `google-cloud` gem. The `google-cloud` gem replaces the old `gcloud` gem. Legacy code can continue to use the `gcloud` gem.

* Namespace is now `Google::Cloud`
* The `google-cloud` gem is now an umbrella package for individual gems
