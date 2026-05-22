#pragma once

#include "imagecacher.hpp"

#include <qquickimageprovider.h>

namespace ryoku::images {

class CachingImageProvider : public QQuickAsyncImageProvider {
public:
    using FillMode = ImageCacher::FillMode;

    explicit CachingImageProvider(FillMode fillMode);

    QQuickImageResponse* requestImageResponse(const QString& id, const QSize& requestedSize) override;

private:
    FillMode m_fillMode;
};

} // namespace ryoku::images
