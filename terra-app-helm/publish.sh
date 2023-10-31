# Publishing a chart under `terra-app-helm` Helm Chart
# At project root, run the following commands (example with aou-sas-chart):

set -eu

CHART_NAME=$1
VERSION=$2

cd terra-app-helm
helm package $CHART_NAME
mkdir -p $CHART_NAME/repo
mv $CHART_NAME-$VERSION.tgz $CHART_NAME/repo/
helm repo index $CHART_NAME/repo/ --url https://storage.googleapis.com/terra-app-helm/$CHART_NAME
gsutil cp -r $CHART_NAME/repo/* gs://terra-app-helm/$CHART_NAME