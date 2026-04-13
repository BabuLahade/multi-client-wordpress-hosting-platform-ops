<?php
// ALB calls this every 30 seconds
// Returns 200 = task is healthy and receives traffic
// Returns 503 = task is unhealthy, ECS kills it and starts a replacement

$client_id = $_ENV['CLIENT_ID'] ?? 'unknown';

// Check 1 — MySQL reachable?
$db = new mysqli($_ENV['DB_HOST'], $_ENV['DB_USER'], $_ENV['DB_PASS'], $_ENV['DB_NAME']);
if ($db->connect_error) {
    http_response_code(503);
    error_log(json_encode([
        'client_id' => $client_id,
        'log_level' => 'ERROR',
        'source'    => 'health-check',
        'message'   => 'DB fail: ' . $db->connect_error
    ]));
    die('DB_FAIL');
}

// Check 2 — Valkey reachable?
$redis = new Redis();
if (!$redis->connect($_ENV['VALKEY_HOST'], 6379)) {
    http_response_code(503);
    error_log(json_encode([
        'client_id' => $client_id,
        'log_level' => 'ERROR',
        'source'    => 'health-check',
        'message'   => 'Valkey connection failed'
    ]));
    die('VALKEY_FAIL');
}

// Both healthy — return 200
http_response_code(200);
echo json_encode(['status' => 'healthy', 'client_id' => $client_id]);