<?php
header('Content-Type: application/json');
include 'conexao.php';

$codigo = $_POST['codigo'];
$lat = $_POST['lat'];
$lng = $_POST['lng'];
$motoboy_id = $_POST['motoboy_id'];
// Novos campos
$vendedor_id = $_POST['vendedor_id']; // ID da loja (VEND-XXXX)
$pedido_id = $_POST['pedido_id'];     // Número do pedido digitado

// Faxina automática
$conn->query("DELETE FROM sessoes_rastreio WHERE ultima_atualizacao < (NOW() - INTERVAL 1 DAY)");
$conn->query("DELETE FROM sessoes_rastreio WHERE codigo = '$codigo'");

// Insere com os novos dados
$stmt = $conn->prepare("INSERT INTO sessoes_rastreio (codigo, latitude, longitude, motoboy_unique_id, vendedor_unique_id, pedido_id) VALUES (?, ?, ?, ?, ?, ?)");
$stmt->bind_param("sddsss", $codigo, $lat, $lng, $motoboy_id, $vendedor_id, $pedido_id);

if ($stmt->execute()) {
    echo json_encode(["status" => "sucesso"]);
} else {
    echo json_encode(["status" => "erro", "msg" => $conn->error]);
}
$conn->close();
?>