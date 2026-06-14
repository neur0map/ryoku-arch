#pragma once

#include "audioprovider.hpp"

#ifdef RYOKU_HAS_CAVA
#include <cava/cavacore.h>
#endif

#include <qqmlintegration.h>

namespace ryoku::services {

#ifdef RYOKU_HAS_CAVA
class CavaProcessor : public AudioProcessor {
    Q_OBJECT

public:
    explicit CavaProcessor(QObject* parent = nullptr);
    ~CavaProcessor();

    void setBars(int bars);
    void setNoiseReduction(double noiseReduction);
    void setAutoSens(bool autoSens);

signals:
    void valuesChanged(QVector<double> values);

protected:
    void process() override;

private:
    struct cava_plan* m_plan;
    double* m_in;
    double* m_out;

    int m_bars;
    double m_noiseReduction = 0.85;
    bool m_autoSens = true;
    QVector<double> m_values;

    void reload();
    void initCava();
    void cleanup();
};
#endif

class CavaProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(qreal noiseReduction READ noiseReduction WRITE setNoiseReduction NOTIFY noiseReductionChanged)
    Q_PROPERTY(bool autoSens READ autoSens WRITE setAutoSens NOTIFY autoSensChanged)

    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)

public:
    explicit CavaProvider(QObject* parent = nullptr);

    [[nodiscard]] int bars() const;
    void setBars(int bars);

    [[nodiscard]] qreal noiseReduction() const;
    void setNoiseReduction(qreal noiseReduction);

    [[nodiscard]] bool autoSens() const;
    void setAutoSens(bool autoSens);

    [[nodiscard]] QVector<double> values() const;

signals:
    void barsChanged();
    void noiseReductionChanged();
    void autoSensChanged();
    void valuesChanged();

private:
    int m_bars;
    qreal m_noiseReduction = 0.85;
    bool m_autoSens = true;
    QVector<double> m_values;

    void updateValues(QVector<double> values);
};

} // namespace ryoku::services
