# Publishing `terra-app-helm` Helm Chart
At project root, run the following commands (example with aou-rstudio-chart):
```
cd terra-app-helm
helm package aou-rstudio-chart
mkdir aou-rstudio-chart/repo
mv aou-rstudio-chart-0.1.0.tgz aou-rstudio-chart/repo/
helm repo index aou-rstudio-chart/repo/ --url https://storage.googleapis.com/terra-app-helm/aou-rstudio-chart
gsutil cp -r aou-rstudio-chart/repo/* gs://terra-app-helm/aou-rstudio-chart
```