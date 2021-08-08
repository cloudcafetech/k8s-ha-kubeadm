#!/bin/sh
# ETCD Restore Script

ETCDCTL_API=3
BUCKET=prodetcd
MINIO_SERVER=172.31.21.248
AWS_ACCESS_KEY_ID=admin
AWS_SECRET_ACCESS_KEY=admin2675
NOW=$(date +'%d%m%Y-%H%M%S')

DIR="$(pwd)/bkp-$NOW"
rm -rf "${DIR}"
mkdir -p "${DIR}/etcd"

# Install Minio Client
if ! command -v mc &> /dev/null;
then
 echo "Installing Minio Client."
 wget https://dl.min.io/client/mc/release/linux-amd64/mc; chmod +x mc; mv -v mc /usr/local/bin/mc
fi

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
    'k8s.gcr.io/etcd:3.5.0-0' \
    /bin/sh -c "etcdctl snapshot restore '/backup/$FILE' ; mv /default.etcd/member/ /var/lib/etcd/"

# Remove SNAP file due to ETCD "member unknown"
rm -rf /var/lib/etcd/member/snap/*.snap

# Validate all restored files under temporay backup
for f in ca.crt ca.key front-proxy-ca.crt front-proxy-ca.key sa.key sa.pub "$FILE"
do
 if [ ! -f $DIR/$f ]; then
  echo "File ($f) not found in $DIR .."
  echo "Please restore files properly, rerun etcd-restrore.sh"
  break
 fi
done

for e in ca.crt ca.key
do
 if [ ! -f $DIR/etcd/$e ]; then
  echo "File ($e) not found in $DIR/etcd .."
  echo "Please restore files properly, rerun etcd-restrore.sh"
  exit
 fi
done

# Validate all restored files under /etc/kubernetes/pki/
for f in ca.crt ca.key front-proxy-ca.crt front-proxy-ca.key sa.key sa.pub
do
 if [ ! -f /etc/kubernetes/pki/$f ]; then
  echo "File ($f) not found .."
  echo "Please restore files properly, rerun etcd-restrore.sh"
  break
 fi
done

# Validate all restored files under /etc/kubernetes/pki/etcd/
for e in ca.crt ca.key
do
 if [ ! -f /etc/kubernetes/pki/etcd/$e ]; then
  echo "File ($e) not found .."
  echo "Please restore files properly, rerun etcd-restrore.sh"
  exit
 fi
done

# Validate etcd folder under /var/lib
if [ ! -d /var/lib/etcd ]; then
 echo "Folder (etcd) not found under /var/lib .."
 echo "Please restore files properly, rerun etcd-restrore.sh"
 exit
fi

# Initilise Kubernetes
kubeadm init --ignore-preflight-errors=DirAvailable--var-lib-etcd
