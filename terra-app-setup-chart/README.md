# Install terra-set-up chart
```
helm install  --set serviceAccount.annotations.gcpServiceAccount="<value>" -n <namespace> <release-name> ./terra-app-setup-chart
```
# Publish Chart
At project root, run the following commands

```
helm package terra-app-setup-chart
mkdir terra-app-setup-chart/repo
mv terra-app-setup-0.0.1.tgz terra-app-setup-chart/repo
helm repo index terra-app-setup-chart/repo/ --url https://storage.googleapis.com/terra-app-setup-chart
gsutil cp -r terra-app-setup-chart/repo/* gs://terra-app-setup-chart
```