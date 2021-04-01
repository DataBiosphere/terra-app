# Install terra-set-up chart
```
helm install  --set serviceAccount.annotations.gcpServiceAccount="<value>" -n <namespace> <release-name> ./terra-app-setup-chart
```
# Publish Chart
For publishing a new version to prod, at project root, run the following commands.
Note for these changes to take effect in leonardo you will need to update the version in the Dockerfile and reference.conf 
It is very important to re-copy the index.yaml from the remote every time you index the chart
```
helm package terra-app-setup-chart
rm -rf terra-app-setup-chart/repo
mkdir terra-app-setup-chart/repo
gsutil cp -r gs://terra-app-setup-chart/index.yaml terra-app-setup-chart/repo
mv terra-app-setup-[Version in Chart.yaml].tgz terra-app-setup-chart/repo
helm repo index terra-app-setup-chart/repo --url https://storage.googleapis.com/terra-app-setup-chart --merge terra-app-setup-chart/repo/index.yaml
gsutil cp -r terra-app-setup-chart/repo/* gs://terra-app-setup-chart
```

For developing locally

Run this locally to publish your changes (this will not overwrite the version used in prod due to the --merge option).
It is very important to re-copy the index.yaml from the remote every time you index the chart
```
VERSION=[Version in Chart.yaml]
helm package terra-app-setup-chart
rm -rf terra-app-setup-chart/repo
mkdir -p terra-app-setup-chart/repo
gsutil cp -r gs://terra-app-setup-chart/index.yaml terra-app-setup-chart/repo
mv terra-app-setup-$VERSION.tgz terra-app-setup-chart/repo
helm repo index terra-app-setup-chart/repo --url https://storage.googleapis.com/terra-app-dev --merge terra-app-setup-chart/repo/index.yaml
gsutil cp -r terra-app-setup-chart/repo/* gs://terra-app-setup-chart
```

Now, to get leo to use your chart, Run this in your fiab, while you are in the leonardo docker image.
Note that if you already have a running app, the rm will fail because the certs are in use. See subsequent set of commands.

If no apps are running:
```
VERSION=[Version in Chart.yaml]
cd leonardo
rm  -rf terra-app-setup
helm pull terra-app-setup-charts/terra-app-setup --version $VERSION --untar
```
If an app is running:
```
VERSION=[Version in Chart.yaml]
cd leonardo
rm  -rf terra-app-setup # will fail, its ok
helm pull terra-app-setup-charts/terra-app-setup --version $VERSION 
mkdir temp
tar -xf terra-app-setup-$VERSION.tgz -C temp --strip-components=1
cp temp/* terra-app-setup #will fail, its ok
```

Now, add the following to `/etc/leonardo.conf` in the leonardo docker image within your fiab
```
terra-app-setup-chart {
  chart-name = "/leonardo/terra-app-setup"
  chart-version = "[your version here]"
}
```

Next, restart leonardo in your fiab via
```
exit
docker restart firecloud_leonardo-app_1 
```

Apps you create via your fiab leonardo will now use the appropriate chart




