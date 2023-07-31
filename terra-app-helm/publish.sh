# Publishing a chart under `terra-app-helm` Helm Chart
# At project root, run the following commands (example with aou-sas-chart):

set -eu

CHART_NAME=$1

cd terra-app-helm
helm package $CHART_NAME
mkdir $CHART_NAME/repo
mv $CHART_NAME-0.1.0.tgz $CHART_NAME/repo/
helm repo index $CHART_NAME/repo/ --url https://storage.googleapis.com/terra-app-helm/$CHART_NAME
gsutil cp -r $CHART_NAME/repo/* gs://terra-app-helm/$CHART_NAME