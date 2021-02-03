# Jupyter

This app descriptor demonstrates launching the [Jupyter](https://jupyter.org/) app. Specifically, it launches the [terra-jupyter-gatk](https://github.com/DataBiosphere/terra-docker/tree/master/terra-jupyter-gatk) image which is the default notebook image in Terra.

It does not require any data inputs. Example launch command:

```
./terra-app-local.sh install -f apps/jupyter/app.yaml
```
