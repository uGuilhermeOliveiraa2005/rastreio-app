<?php
error_reporting(0);
ini_set('display_errors', 0);
header('Content-Type: application/json; charset=utf-8');
include 'conexao.php';

$vendedor_uid = $_GET['vendedor_id'];

if (!$vendedor_uid) { echo json_encode([]); exit; }

// A query agora faz um JOIN com a tabela de rastreio para pegar o código e o pedido
// APENAS se o rastreio for para ESTE vendedor (s.vendedor_unique_id = vend.unique_id)
$sql = "
    SELECT 
        m.unique_id,
        m.nome,
        s.codigo as codigo_rastreio,
        s.pedido_id
    FROM motoboys m
    JOIN vinculos v ON m.id = v.motoboy_id
    JOIN vendedores vend ON v.vendedor_id = vend.id
    LEFT JOIN sessoes_rastreio s ON s.motoboy_unique_id = m.unique_id 
                                 AND s.vendedor_unique_id = vend.unique_id
    WHERE vend.unique_id = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $vendedor_uid);
$stmt->execute();
$result = $stmt->get_result();

$lista = [];
while ($row = $result->fetch_assoc()) {
    $lista[] = [
        "id" => $row['unique_id'],
        "nome" => $row['nome'],
        "online" => !empty($row['codigo_rastreio']), // Se tem código, está online
        "rastreio" => $row['codigo_rastreio'],
        "pedido" => $row['pedido_id']
    ];
}

echo json_encode($lista);
$conn->close();
?>