<?php
// Auto-wake watchdog
@exec('/bin/bash /home/virilax/public_html/mostager.virilax.shop/runner.sh > /dev/null 2>&1 &');

// Wait 1.5 seconds for server to be ready
usleep(1500000);

// Retry proxying the current request
$uri = $_SERVER['REQUEST_URI'] ?? '/';
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$url = 'http://127.0.0.1:19080' . $uri;

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);
curl_setopt($ch, CURLOPT_HEADER, true);

if ($method === 'POST') {
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, file_get_contents('php://input'));
}

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$header_size = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
curl_close($ch);

if ($http_code > 0 && $response !== false) {
    http_response_code($http_code);
    $header_text = substr($response, 0, $header_size);
    $body = substr($response, $header_size);
    
    foreach (explode("\r\n", $header_text) as $hdr) {
        if (!empty($hdr) && stripos($hdr, 'Transfer-Encoding') === false && stripos($hdr, 'HTTP/') === false) {
            header($hdr, false);
        }
    }
    echo $body;
} else {
    // If still starting up, meta-refresh in 1 second
    echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="1"><title>جاري تشغيل النظام...</title></head><body style="font-family:sans-serif;text-align:center;padding:50px;"><h2>جاري تجهيز النظام وتشغيله، يرجى الانتظار ثوانٍ معدودة...</h2></body></html>';
}
