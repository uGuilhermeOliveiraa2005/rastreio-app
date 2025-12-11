<?php
error_reporting(0);
ini_set('display_errors', 0);
header('Content-Type: application/json; charset=utf-8');
include 'conexao.php';

$motoboy_uid = $_GET['motoboy_id'];

if (!$motoboy_uid) {
    echo json_encode([]);
    exit;
}

// Busca sessões ativas e faz JOIN para pegar o nome da loja
$sql = "
    SELECT 
        s.codigo, 
        s.pedido_id, 
        v.nome as nome_loja,
        s.ultima_atualizacao
    FROM sessoes_rastreio s
    LEFT JOIN vendedores v ON s.vendedor_unique_id = v.unique_id
    WHERE s.motoboy_unique_id = ?
    ORDER BY s.ultima_atualizacao DESC
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $motoboy_uid);
$stmt->execute();
$result = $stmt->get_result();

$lista = [];
while ($row = $result->fetch_assoc()) {
    $lista[] = [
        "codigo" => $row['codigo'],
        "pedido" => $row['pedido_id'],
        "loja" => $row['nome_loja'] ?? "Loja Desconhecida",
        "hora" => date("H:i", strtotime($row['ultima_atualizacao']))
    ];
}

echo json_encode($lista);
$conn->close();
?>