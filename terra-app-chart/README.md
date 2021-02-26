# Publishing `terra-app-chart` Helm Chart
At project root, run the following commands:
```
helm package terra-app-chart
mkdir terra-app-chart/repo
mv terra-app-0.2.0.tgz terra-app-chart/repo/
helm repo index terra-app-chart/repo/ --url https://storage.googleapis.com/terra-app-charts
gsutil cp -r terra-app-chart/repo/* gs://terra-app-charts
```
