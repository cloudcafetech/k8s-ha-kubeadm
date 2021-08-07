#!/bin/sh
# ETCD Restore Script

ETCDCTL_API=3
BUCKET=prodetcd
MINIO_SERVER=172.31.25.231
AWS_ACCESS_KEY_ID=admin
AWS_SECRET_ACCESS_KEY=admin2675
NOW=$(date +'%d%m%Y-%H%M%S')

DIR="$(pwd)/bkp-$NOW"
rm -rf "${DIR}"
mkdir -p "${DIR}"

# Downloading files from Minio Bucket
echo "Downloading files from Minio Bucket"
mc config host add minio http://$MINIO_SERVER:9000 $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY --insecure
mc mb minio/$BUCKET --insecure
mc cp -a minio/$BUCKET/ca.crt $DIR/
mc cp -a minio/$BUCKET/ca.key $DIR/
FILE=`mc ls  minio/$BUCKET/ | grep etcd-snapshot | tail --lines=1 | awk '{print $5}'`
mc cp -a minio/$BUCKET/$FILE $DIR/

# Restore Certificate
mkdir -p /etc/kubernetes/pki
chmod 0644 $DIR/ca.crt
chmod 0600 $DIR/ca.key
cp $DIR/ca.crt /etc/kubernetes/pki/ca.crt
cp $DIR/ca.key /etc/kubernetes/pki/ca.key

# Restore ETCD DB
mkdir -p /var/lib/etcd
docker run --rm \
    -v "$DIR:/backup" \
    -v '/var/lib/etcd:/var/lib/etcd' \
    --env ETCDCTL_API=3 \
    'k8s.gcr.io/etcd-amd64:3.1.12' \
    /bin/sh -c "etcdctl snapshot restore '/backup/$FILE' ; mv /default.etcd/member/ /var/lib/etcd/"

# Initilise Kubernetes
kubeadm init --ignore-preflight-errors=DirAvailable--var-lib-etcd