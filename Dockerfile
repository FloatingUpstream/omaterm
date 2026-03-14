ARG BASE_IMAGE=archlinux:latest
FROM ${BASE_IMAGE}

ARG USERNAME=omaterm
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash

RUN if [ -f /etc/arch-release ]; then \
      pacman -Syu --noconfirm --needed bash ca-certificates curl git shadow sudo; \
    elif [ -f /etc/debian_version ]; then \
      apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl git sudo; \
    else \
      echo "Unsupported base image" >&2; \
      exit 1; \
    fi

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN existing_group="$(getent group ${USER_GID} | cut -d: -f1 || true)" \
    && if [ -n "$existing_group" ]; then \
      group_name="$existing_group"; \
    else \
      groupadd --gid ${USER_GID} ${USERNAME}; \
      group_name="${USERNAME}"; \
    fi \
    && if id -u ${USER_UID} >/dev/null 2>&1; then \
      user_name="$(getent passwd ${USER_UID} | cut -d: -f1)"; \
      usermod --gid "$group_name" --home /home/${USERNAME} --move-home "$user_name"; \
      usermod --login ${USERNAME} "$user_name"; \
    else \
      useradd --uid ${USER_UID} --gid "$group_name" -m -s /bin/bash ${USERNAME}; \
    fi \
    && printf '%s ALL=(ALL) NOPASSWD:ALL\n' ${USERNAME} >/etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

COPY --chown=${USER_UID}:${USER_GID} . /tmp/omaterm

USER ${USERNAME}
WORKDIR /tmp/omaterm

RUN OMATERM_CONTAINER=1 OMATERM_NONINTERACTIVE=1 ./install.sh && rm -rf /tmp/omaterm

WORKDIR /workspace
CMD ["/bin/bash", "-l"]
