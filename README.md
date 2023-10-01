docker run -e "NAME=Scanner" -e "MODEL=MFC-L2710DW" -e "IPADDRESS=192.168.1.41" -it --name=brscan-container -v /mnt/scans:/scans --net=host edfabre/brother-brscan-skey

