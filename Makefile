###############################################################################
#
# Makefile for OmicsHub Workspace
#
# author : James A. Perez
# 
###############################################################################

include make_env

msg = ensure all required environment variables are exported
ifeq ($(S3_MNT_PATH),)
$(error S3_MNT_PATH not defined -- $(msg))
endif
ifeq ($(EFS_MNT_PATH),)
$(error EFS_MNT_PATH not defined -- $(msg))
endif
ifeq ($(S3_BUCKET_SEQ),)
$(error S3_BUCKET_SEQ not defined -- $(msg))
endif
ifeq ($(S3_BUCKET_MINIWDL),)
$(error S3_BUCKET_MINIWDL not defined -- $(msg))
endif
# ifeq ($(EFS_SHARE_DNS),)
# $(error EFS_SHARE_DNS not defined -- $(msg))
# endif
# ifeq ($(EFS_MINIWDL_DNS),)
# $(error EFS_MINIWDL_DNS not defined -- $(msg))
# endif
ifeq ($(LINUX_UID),)
$(error LINUX_UID not defined -- $(msg))
endif

env:
	@echo OMICSHUB_HOME=$(OMICSHUB_HOME)
	@echo EFS_SHARE_DNS=$(EFS_SHARE_DNS)
	@echo EFS_MINIWDL_DNS=$(EFS_MINIWDL_DNS)
	@echo LINUX_UID=$(LINUX_UID)
	@echo HOST_PATH_S3_SEQ=$(HOST_PATH_S3_SEQ) 
	@echo HOST_PATH_S3_MINIWDL=$(HOST_PATH_S3_MINIWDL) 
	@echo HOST_PATH_EFS_SHARE=$(HOST_PATH_EFS_SHARE) 
	@echo HOST_PATH_EFS_MINIWDL=$(HOST_PATH_EFS_MINIWDL)

MAKEDIR=sh -c '\
  if [ ! -d $$1 ] ; then \
  	echo "installing :: $$1"; \
  	sudo install -d $$1 $(INSTALL_OPTS) && \
		sudo chgrp $(LINUX_UID) $$1; else \
  	echo "already installed ::  $$1"; \
  fi' MAKEDIR

init:
	@( \
	  ${MAKEDIR} $(OMICSHUB_HOME); \
	  ${MAKEDIR} $(OMICSHUB_HOME)/s3; \
	)
	
mount-paths:	
	@( \
	  ${MAKEDIR} $(OMICSHUB_HOME); \
	  ${MAKEDIR} $(HOST_PATH_S3_SEQ); \
	  ${MAKEDIR} $(HOST_PATH_S3_MINIWDL); \
	  ${MAKEDIR} $(HOST_PATH_EFS_SHARE); \
	  ${MAKEDIR} $(HOST_PATH_EFS_MINIWDL); \
	)

MOUNT_NFS=sh -c '\
  if ! grep -qs "$$2" /proc/mounts; then \
  	echo "mounting :: $$1:/ $$2"; \
	  sudo mount -t nfs $(NFS_OPTS) $$1:/ $$2; else \
	  echo "already mounted ::  $$1:/ $$2"; \
  fi' MOUNT_NFS

MOUNT_S3=sh -c '\
  if ! grep -qs "$$2" /proc/mounts; then \
  	echo "mounting :: s3://$$1:/ $$2"; \
	  s3fs $$1 $$2 $(S3FS_OPTS); \
	  sudo chmod -R 755 $$2; else \
	  echo "already mounted ::  s3://$$1:/ $$2"; \
  fi' MOUNT_S3

MAKELINK=sh -c '\
  if [ ! -L $$2 ] ; then \
  	echo "linking :: $$1 -> $$2"; \
	  mkdir -p $$1; \
  	ln -sf $$1 $$2; else \
  	echo "already linked :: $$1 -> $$2"; \
  fi' MAKELINK

mount-efs:
	@( \
	  ${MOUNT_NFS} $(EFS_MINIWDL_DNS) $(HOST_PATH_EFS_MINIWDL); \
	  ${MOUNT_NFS} $(EFS_SHARE_DNS) $(HOST_PATH_EFS_SHARE); \
		${MAKELINK} $(HOST_PATH_EFS_SHARE)/notebooks $(SYMLINK_EFS_NOTEBOOKS); \
	  ${MAKELINK} $(HOST_PATH_EFS_MINIWDL)/wdl $(SYMLINK_EFS_WDL); \
	  ${MAKELINK} $(HOST_PATH_EFS_MINIWDL)/input_json $(SYMLINK_EFS_INPUT_JSON); \
	  ${MAKELINK} $(HOST_PATH_EFS_MINIWDL)/miniwdl_run $(SYMLINK_EFS_MINIWDL); \
	)

mount-s3:
	@( \
	  ${MOUNT_S3} $(S3_BUCKET_SEQ) $(HOST_PATH_S3_SEQ); \
	  ${MOUNT_S3} $(S3_BUCKET_MINIWDL) $(HOST_PATH_S3_MINIWDL) \
	  ${MAKELINK} $(HOST_PATH_S3_SEQ) $(SYMLINK_S3_SEQ); \
	  ${MAKELINK} $(HOST_PATH_S3_MINIWDL) $(SYMLINK_S3_MINIWDL); \
	)

UNMOUNT=sh -c '\
  if grep -qs "$$1" /proc/mounts; then \
  	echo "unmounting :: $$1"; \
	sudo umount -l $$1; else \
	echo "mount does not exist ::  $$1"; \
  fi' UNMOUNT 

unmount:
	@( \
	  ${UNMOUNT} $(HOST_PATH_S3_SEQ); \
	  ${UNMOUNT} $(HOST_PATH_S3_MINIWDL); \
	  ${UNMOUNT} $(HOST_PATH_EFS_SHARE); \
	  ${UNMOUNT} $(HOST_PATH_EFS_MINIWDL); \
	)

RMLINK=sh -c '\
  if [ -L $$1 ] ; then \
  	echo "removing link :: $$1"; \
  	rm $$1; else \
  	echo "link does not exist :: $$1"; \
  fi' RMLINK

unlink:
	@( \
	  ${RMLINK} $(SYMLINK_S3_SEQ); \
	  ${RMLINK} $(SYMLINK_S3_MINIWDL); \
	  ${RMLINK} $(SYMLINK_EFS_NOTEBOOKS); \
	  ${RMLINK} $(SYMLINK_EFS_WDL); \
	  ${RMLINK} $(SYMLINK_EFS_INPUT_JSON); \
	  ${RMLINK} $(SYMLINK_EFS_MINIWDL); \
	)

#mounts: mount-paths mount-efs mount-s3
mounts: mount-paths mount-s3

#remount: unmount mount-efs mount-s3
remount: unmount mount-s3

jupyter:
	jupyterhub --ip 0.0.0.0 --port 8000 -f /etc/jupyterhub/jupyterhub_config.py

workspace: init links jupyter

RMDIR=sh -c '\
  if [ -d $$1 ] ; then \
  	echo "removing directory :: $$1"; \
  	sudo rmdir $$1; else \
  	echo "directory does not exist :: $$1"; \
  fi' RMDIR

clean-host: unmount
	@( \
	  ${RMDIR} $(HOST_PATH_S3_SEQ); \
	  ${RMDIR} $(HOST_PATH_S3_MINIWDL); \
	  ${RMDIR} $(HOST_PATH_EFS_SHARE); \
	  ${RMDIR} $(HOST_PATH_EFS_MINIWDL); \
	)

clean-pod: unlink 
	@( \
	  ${RMDIR} $(OMICSHUB_HOME)/s3; \
	  ${RMDIR} $(OMICSHUB_HOME); \
	)
