FROM rclone/rclone:1.62

ENV PUID=1026
ENV PGID=100
ENV EXEC_SCRIPT=/config/rclone/PhotoSSD1_on_pcloud.sh

COPY start-sync.sh /usr/local/bin/

ENTRYPOINT [ "start-sync.sh" ]