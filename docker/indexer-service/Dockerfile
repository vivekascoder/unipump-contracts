FROM node:20-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS prod

RUN mkdir -p /app
COPY pnpm-lock.yaml /app
WORKDIR /app

COPY . /app
RUN pnpm install -P
# RUN pnpm run build

FROM prod
COPY --from=prod /app/node_modules /app/node_modules
# COPY --from=prod /app/dist /app/dist
EXPOSE 42069
CMD [ "pnpm", "indexer:start" ]