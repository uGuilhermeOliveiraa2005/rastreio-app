<?php
error_reporting(0);
ini_set('display_errors', 0);
header('Content-Type: application/json; charset=utf-8');
include 'conexao.php';

$motoboy_uid = $_GET['motoboy_id'];

if (!$motoboy_uid) { echo json_encode([]); exit; }

$sql = "
    SELECT vend.unique_id, vend.nome
    FROM vendedores vend
    JOIN vinculos v ON vend.id = v.vendedor_id
    JOIN motoboys m ON v.motoboy_id = m.id
    WHERE m.unique_id = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $motoboy_uid);
$stmt->execute();
$result = $stmt->get_result();

$lista = [];
while ($row = $result->fetch_assoc()) {
    $lista[] = [
        "id" => $row['unique_id'],
        "nome" => $row['nome']
    ];
}

echo json_encode($lista);
$conn->close();
?>