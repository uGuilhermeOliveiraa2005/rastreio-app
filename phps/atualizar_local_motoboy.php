<?php
header('Content-Type: application/json');
include 'conexao.php';

// Recebe: ENT-1234567, latitude, longitude
$motoboy_id = $_POST['motoboy_id'];
$lat = $_POST['lat'];
$lng = $_POST['lng'];

if (!$motoboy_id || !$lat || !$lng) {
    echo json_encode(["status" => "erro", "msg" => "Dados incompletos"]);
    exit;
}

// ATUALIZAÇÃO EM MASSA:
// Atualiza a localização de TODAS as sessões onde o motoboy é o dono.
$sql = "UPDATE sessoes_rastreio 
        SET latitude = ?, longitude = ?, ultima_atualizacao = NOW() 
        WHERE motoboy_unique_id = ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("dds", $lat, $lng, $motoboy_id);

if ($stmt->execute()) {
    echo json_encode([
        "status" => "atualizado", 
        "entregas_afetadas" => $stmt->affected_rows // Mostra quantos pedidos foram atualizados
    ]);
} else {
    echo json_encode(["status" => "erro", "msg" => $conn->error]);
}

$conn->close();
?>