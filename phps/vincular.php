<?php
header('Content-Type: application/json');
include 'conexao.php';

$vendedor_uid = $_POST['vendedor_id']; // Ex: VEND-1234
$motoboy_uid = $_POST['motoboy_id'];   // Ex: MOTO-ABCD

if (!$vendedor_uid || !$motoboy_uid) {
    echo json_encode(["status" => "erro", "msg" => "IDs obrigatórios"]);
    exit;
}

// 1. Acha o Vendedor
$stmtV = $conn->prepare("SELECT id FROM vendedores WHERE unique_id = ?");
$stmtV->bind_param("s", $vendedor_uid);
$stmtV->execute();
$resV = $stmtV->get_result();
if ($resV->num_rows == 0) {
    echo json_encode(["status" => "erro", "msg" => "Vendedor não encontrado"]);
    exit;
}
$vendedor_id_interno = $resV->fetch_assoc()['id'];

// 2. Acha ou Cria o Motoboy
// (Garante que o motoboy exista no banco antes de vincular)
$conn->query("INSERT IGNORE INTO motoboys (unique_id) VALUES ('$motoboy_uid')");
$resM = $conn->query("SELECT id FROM motoboys WHERE unique_id = '$motoboy_uid'");
$motoboy_id_interno = $resM->fetch_assoc()['id'];

// 3. Cria o Vínculo
$stmtLink = $conn->prepare("INSERT IGNORE INTO vinculos (vendedor_id, motoboy_id) VALUES (?, ?)");
$stmtLink->bind_param("ii", $vendedor_id_interno, $motoboy_id_interno);

if ($stmtLink->execute()) {
    echo json_encode(["status" => "sucesso", "msg" => "Vinculado com sucesso!"]);
} else {
    echo json_encode(["status" => "erro", "msg" => "Erro ao criar vínculo"]);
}
$conn->close();
?>