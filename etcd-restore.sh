#!/bin/sh
# ETCD Restore Script

ETCDCTL_API=3
BUCKET=prodetcd
MINIO_SERVER=172.31.30.115
MINIO_PORT=9000
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

# Install ETCD Utils
if ! command -v etcdutl &> /dev/null;
then
 echo "Install ETCD Utils."
 curl -L https://github.com/etcd-io/etcd/releases/download/v3.5.0/etcd-v3.5.0-linux-amd64.tar.gz -o etcd-v3.5.0-linux-amd64.tar.gz
 tar zxvf etcd-v3.5.0-linux-amd64.tar.gz
 mv etcd-v3.5.0-linux-amd64/etcd*tl /usr/local/bin/
 rm -rf etcd-v3.5.0-linux-amd64*
fi

# Checking Minio S3 Server Response
MTEST=`nc -w 2 -v $MINIO_SERVER $MINIO_PORT </dev/null; echo $?`
if [[ "$MTEST" == "0" ]]; then
  echo "OK - Load Balancer ($MINIO_SERVER) on port ($MINIO_PORT) responding."
else
  echo "NOT Good - Minio S3 Server ($MINIO_SERVER) on port ($MINIO_PORT) NOT responding."
  echo "Please Check Minio S3 Server ($MINIO_SERVER) on port ($MINIO_PORT), before proceeding."
  exit
fi

# Downloading files from Minio Bucket
echo "Downloading files from Minio Bucket"
mc config host add minio http://$MINIO_SERVER:$MINIO_PORT $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY --insecure
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
etcdutl snapshot restore $DIR/$FILE --data-dir $DIR/restore-etcd; mv $DIR/restore-etcd/member /var/lib/etcd/

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
