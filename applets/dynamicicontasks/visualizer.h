#pragma once

#include <QProcess>
#include <QVariantList>
#include <qqmlregistration.h>

class CavaVisualizer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList values READ values NOTIFY valuesChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit CavaVisualizer(QObject *parent = nullptr);

    QVariantList values() const;
    bool running() const;

    Q_INVOKABLE void configure(bool enabled, int barCount);

Q_SIGNALS:
    void valuesChanged();
    void runningChanged();

private Q_SLOTS:
    void readOutput();

private:
    void stop();

    QProcess m_process;
    QVariantList m_values;
    QByteArray m_buffer;
    int m_barCount = 24;
};
