# RStudio

This app descriptor demonstrates launching the [RStudio](https://rstudio.com/) app. Specifically, it launches the [anvil-rstudio-bioconductor](https://github.com/anvilproject/anvil-docker/tree/master/anvil-rstudio-bioconductor) image which is the default RStudio image in Terra.

It does not require any data inputs. Example launch command:

```
./terra-app-local.sh install -f apps/rstudio/app.yaml
```
