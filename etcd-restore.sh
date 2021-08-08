#!/bin/sh
# ETCD Restore Script

ETCDCTL_API=3
BUCKET=prodetcd
MINIO_SERVER=172.31.29.182
AWS_ACCESS_KEY_ID=admin
AWS_SECRET_ACCESS_KEY=admin2675
NOW=$(date +'%d%m%Y-%H%M%S')

DIR="$(pwd)/bkp-$NOW"
rm -rf "${DIR}"
mkdir -p "${DIR}/etcd"

# Downloading files from Minio Bucket
echo "Downloading files from Minio Bucket"
mc config host add minio http://$MINIO_SERVER:9000 $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY --insecure
mc mb minio/$BUCKET --insecure
mc mb minio/$BUCKET/etcd --insecure

mc find minio/$BUCKET --name "*ca.*" --exec "mc cp {} $DIR/"
mc find minio/$BUCKET --name "sa.*" --exec "mc cp {} $DIR/"

mc find minio/$BUCKET/etcd/ --name "*ca.*" --exec "mc cp {} $DIR/etcd/"

FILE=`mc ls  minio/$BUCKET/ | grep etcd-snapshot | tail --lines=1 | awk '{print $5}'`
mc cp -a minio/$BUCKET/$FILE $DIR/

# Restore Kube Certificate
mkdir -p /etc/kubernetes/pki/etcd
chmod 0644 $DIR/*.crt
chmod 0600 $DIR/*.key
chmod 0600 $DIR/*.pub
cp $DIR/*ca.* /etc/kubernetes/pki/
cp $DIR/sa.* /etc/kubernetes/pki/

# Restore ETCD Certificate
chmod 0644 $DIR/etcd/*.crt
chmod 0600 $DIR/etcd/*.key
cp $DIR/etcd/*ca.* /etc/kubernetes/pki/etcd/

# Restore ETCD DB
mkdir -p /var/lib/etcd
docker run --rm \
    -v "$DIR:/backup" \
    -v '/var/lib/etcd:/var/lib/etcd' \
    --env ETCDCTL_API=3 \
    'k8s.gcr.io/etcd-amd64:3.1.12' \
    /bin/sh -c "etcdctl snapshot restore '/backup/$FILE' ; mv /default.etcd/member/ /var/lib/etcd/"

# Remove SNAP file due to ETCD "member unknown"
rm -rf /var/lib/etcd/member/snap/*.snap

# Initilise Kubernetes
kubeadm init --ignore-preflight-errors=DirAvailable--var-lib-etcd
