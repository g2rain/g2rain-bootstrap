# 官方 CPU 镜像已含 Docling、TableFormer 与模型权重。此处只替换 OpenCV，避免旧内核无法加载 Qt。
# 入口以 root 纠正 HF_HOME、缺 MiniLM 时幂等预拉，再降权到 1001 启动。
ARG BASE_IMAGE=ghcr.io/docling-project/docling-serve-cpu:v1.29.0
FROM ${BASE_IMAGE}

USER 0
COPY --chown=1001:0 fix-opencv.py /tmp/fix-opencv.py
RUN python3 /tmp/fix-opencv.py && rm -f /tmp/fix-opencv.py

COPY start-docling-serve.sh /usr/local/bin/start-docling-serve.sh
RUN chmod 755 /usr/local/bin/start-docling-serve.sh

ENTRYPOINT ["/usr/local/bin/start-docling-serve.sh"]
CMD ["docling-serve", "run"]
