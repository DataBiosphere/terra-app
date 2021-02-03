# cellxgene

This app descriptor demonstrates launching the [cellxgene](https://chanzuckerberg.github.io/cellxgene/) app.

It utilizes a startup script and excepts a data file to be passed to it at launch time. Example launch command:

```
./terra-app-local.sh install -f apps/cellxgene/app.yaml -a /data/pbmc3k.h5ad
```
