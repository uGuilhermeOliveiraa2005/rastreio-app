<?php
header('Content-Type: application/json');
include 'conexao.php';

$codigo = $_GET['codigo'];

$result = $conn->query("SELECT latitude, longitude FROM sessoes_rastreio WHERE codigo='$codigo'");

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode([
        "status" => "ativo",
        "lat" => (float)$row['latitude'], 
        "lng" => (float)$row['longitude']
    ]);
} else {
    echo json_encode(["status" => "inativo"]);
}
$conn->close();
?>