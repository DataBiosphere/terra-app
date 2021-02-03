# cirrocumulus

This app descriptor demonstrates launching the [cirrocumulus](https://cirrocumulus.readthedocs.io/en/latest/) app.

It utilizes a startup script and excepts a data file to be passed to it at launch time. Example launch command:

```
./terra-app-local.sh install -f apps/cirrocumulus/app.yaml -a /data/pbmc3k.h5ad
```
