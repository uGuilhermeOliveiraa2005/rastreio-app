<?php
header('Content-Type: application/json');
include 'conexao.php';

$codigo = $_POST['codigo'];
$lat = $_POST['lat'];
$lng = $_POST['lng'];

$sql = "UPDATE sessoes_rastreio SET latitude='$lat', longitude='$lng' WHERE codigo='$codigo'";

if ($conn->query($sql) === TRUE) {
    echo json_encode(["status" => "atualizado"]);
} else {
    echo json_encode(["status" => "erro"]);
}
$conn->close();
?>