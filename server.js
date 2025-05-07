const express = require('express');
const bodyParser = require('body-parser');
const { SerialPort } = require('serialport');
const cors = require('cors');

const app = express();
const PORT = 3000;

const allowedOrigins = [
    'https://business-portal.test',
    'https://app-staging.sixpac.com',
    'https://app.sixpac.com'
];

app.use(cors({
    origin: function (origin, callback) {
        if (!origin) return callback(null, true);

        if (allowedOrigins.includes(origin)) {
            return callback(null, true);
        } else {
            return callback(new Error('Not allowed by CORS'));
        }
    },
    methods: ['GET', 'POST'],
    credentials: true,
}));

app.use(bodyParser.json());

app.get('/list-ports', async (req, res) => {
    try {
        const serialPorts = await SerialPort.list();

        res.json({
            message: 'Available serial ports',
            serialPorts,
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to list devices', detail: error.message });
    }
});

app.post('/open-drawer', async (req, res) => {
    const { portPath, type } = req.body;

    if (type !== 'serial') {
        return res.status(400).json({ error: 'Unsupported device type. Use "serial".' + portPath  + type});
    }

    try {
        const port = new SerialPort({
            path: portPath,
            baudRate: 9600,
            autoOpen: false,
        });

        port.open((err) => {
            if (err) {
                return res.status(500).json({ error: 'Failed to open port', detail: err.message });
            }

            const drawerCommand = Buffer.from([0x07]);
            port.write(drawerCommand, (err) => {
                if (err) {
                    return res.status(500).json({ error: 'Failed to send command', detail: err.message });
                }

                console.log('Drawer pulse command (0x07) sent successfully');

                setTimeout(() => {
                    port.close((err) => {
                        if (err) {
                            return res.status(500).json({ error: 'Failed to close port', detail: err.message });
                        }

                        res.json({
                            success: true,
                            message: `Drawer pulse command (0x07) sent successfully on ${portPath}`,
                        });
                    });
                }, 250);
            });
        });
    } catch (error) {
        res.status(500).json({ error: 'Unexpected error', detail: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`\u2705 Cash Drawer Middleware running on http://localhost:${PORT}`);
});
