#pragma once

#include <qcolor.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlengine.h>

class BlobShape;
class BlobInvertedRect;

class BlobGroup : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal smoothing READ smoothing WRITE setSmoothing NOTIFY smoothingChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(qreal shadowStrength READ shadowStrength WRITE setShadowStrength NOTIFY shadowStrengthChanged)
    Q_PROPERTY(qreal shadowSize READ shadowSize WRITE setShadowSize NOTIFY shadowSizeChanged)
    Q_PROPERTY(QColor borderColor READ borderColor WRITE setBorderColor NOTIFY borderColorChanged)
    Q_PROPERTY(qreal borderWidth READ borderWidth WRITE setBorderWidth NOTIFY borderWidthChanged)

public:
    explicit BlobGroup(QObject* parent = nullptr);
    ~BlobGroup() override;

    qreal smoothing() const { return m_smoothing; }

    void setSmoothing(qreal s);

    QColor color() const { return m_color; }

    void setColor(const QColor& c);

    qreal shadowStrength() const { return m_shadowStrength; }
    void setShadowStrength(qreal v);

    qreal shadowSize() const { return m_shadowSize; }
    void setShadowSize(qreal v);

    QColor borderColor() const { return m_borderColor; }
    void setBorderColor(const QColor& c);

    qreal borderWidth() const { return m_borderWidth; }
    void setBorderWidth(qreal v);

    void addShape(BlobShape* shape);
    void removeShape(BlobShape* shape);

    void setInvertedRect(BlobInvertedRect* rect);
    void clearInvertedRect(BlobInvertedRect* rect);

    const QList<BlobShape*>& shapes() const { return m_shapes; }

    BlobInvertedRect* invertedRect() const { return m_invertedRect; }

    void markDirty();
    void markShapeDirty(BlobShape* source);
    void ensurePhysicsUpdated();

signals:
    void smoothingChanged();
    void colorChanged();
    void shadowStrengthChanged();
    void shadowSizeChanged();
    void borderColorChanged();
    void borderWidthChanged();

private:
    qreal m_smoothing = 32.0;
    QColor m_color{ 0x44, 0x88, 0xff };
    qreal m_shadowStrength = 0.0;
    qreal m_shadowSize = 0.0;
    QColor m_borderColor{ 0, 0, 0, 0 };
    qreal m_borderWidth = 0.0;
    QList<BlobShape*> m_shapes;
    BlobInvertedRect* m_invertedRect = nullptr;
    bool m_physicsUpdated = false;
};
