<!-- <?php
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
echo json_encode(['status' => 'healthy', 'client_id' => $client_id]); -->

<?php
// ALB Deep Health Check - SRE Level 1 Auto-Healing
// Returns 200 = task is healthy
// Returns 503 = task is unhealthy, ECS kills it and starts a replacement

// 1. Grab the exact Client ID we injected via Terraform
$client_id = $_ENV['CLIENT_ID'] ?? 'unknown';

// 2. Check MySQL connectivity
// Using WORDPRESS_DB_PASSWORD which ECS securely injects from AWS Secrets Manager
$db = new mysqli(
    $_ENV['WORDPRESS_DB_HOST'],
    $_ENV['WORDPRESS_DB_USER'],
    $_ENV['WORDPRESS_DB_PASSWORD'],
    $_ENV['WORDPRESS_DB_NAME']
);

if ($db->connect_error) {
    http_response_code(503);
    // Output structured JSON so CloudWatch Logs Insights can query it instantly
    error_log(json_encode([
        'client_id' => $client_id,
        'log_level' => 'ERROR',
        'source'    => 'health-check',
        'message'   => 'DB fail: ' . $db->connect_error
    ]));
    die('DB_FAIL');
}

// 3. Check Valkey (Redis) connectivity
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

// Both checks passed — return 200 OK
http_response_code(200);
header('Content-Type: application/json');
echo json_encode(['status' => 'healthy', 'client_id' => $client_id]);
?>