<?php
header('Content-Type: application/json');
include 'conexao.php';
$codigo = $_POST['codigo'];
$conn->query("DELETE FROM sessoes_rastreio WHERE codigo='$codigo'");
echo json_encode(["status" => "finalizado"]);
$conn->close();
?>