FROM ghcr.io/valhalla/valhalla:latest
EXPOSE 8002
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
ENV DATA_DIR=/data
CMD ["/usr/local/bin/start.sh"]
