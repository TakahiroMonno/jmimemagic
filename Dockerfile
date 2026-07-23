# =========================================================
#  jMimeMagic (net.sf.jmimemagic) build & run Dockerfile
#  - ソース/ターゲットが Java 1.6 のため JDK 8 でビルドする
#  - net.sf.jmimemagic.Magic を `file` コマンド風に実行する
# =========================================================

# ---------- Build stage ----------
FROM maven:3.9-eclipse-temurin-8 AS build

WORKDIR /build

# 依存解決を先にキャッシュ（pom だけ先にコピー）
COPY pom.xml .
RUN mvn -B -q dependency:go-offline || true

# ソースをコピーしてビルド
COPY . .

# package でjarを生成し、実行時依存を target/dependency に集める。
#   -DskipTests            : テストをスキップ
#   -Dmaven.javadoc.skip   : javadoc プラグインによる失敗を回避
#   -Dgpg.skip             : GPG 署名（deploy用）を無効化
RUN mvn -B clean package dependency:copy-dependencies \
        -DskipTests \
        -Dmaven.javadoc.skip=true \
        -Dgpg.skip=true

# ---------- Runtime stage ----------
FROM eclipse-temurin:8-jre

WORKDIR /app

# 生成された jar と実行時依存ライブラリをコピー
COPY --from=build /build/target/jmimemagic-*.jar /app/jmimemagic.jar
COPY --from=build /build/target/dependency        /app/lib

# net.sf.jmimemagic.Magic は引数にファイルパスを取り、MIME タイプを表示する。
# 例: docker run --rm -v "$PWD":/data jmimemagic /data/sample.pdf
ENTRYPOINT ["java", "-cp", "/app/jmimemagic.jar:/app/lib/*", "net.sf.jmimemagic.Magic"]