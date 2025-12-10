<?php
header('Content-Type: application/json');
include 'conexao.php';

// Recebe QUEM está pedindo (tipo) e o ID do alvo
$tipo_solicitante = $_POST['tipo']; // 'vendedor' ou 'motoboy'
$meu_id = $_POST['meu_id'];
$alvo_id = $_POST['alvo_id'];

if ($tipo_solicitante == 'vendedor') {
    // Vendedor quer apagar um motoboy
    $sql = "DELETE v FROM vinculos v 
            JOIN vendedores vend ON v.vendedor_id = vend.id 
            JOIN motoboys m ON v.motoboy_id = m.id 
            WHERE vend.unique_id = ? AND m.unique_id = ?";
} else {
    // Motoboy quer apagar um vendedor
    $sql = "DELETE v FROM vinculos v 
            JOIN motoboys m ON v.motoboy_id = m.id 
            JOIN vendedores vend ON v.vendedor_id = vend.id 
            WHERE m.unique_id = ? AND vend.unique_id = ?";
}

$stmt = $conn->prepare($sql);
$stmt->bind_param("ss", $meu_id, $alvo_id);

if ($stmt->execute()) {
    echo json_encode(["status" => "sucesso", "msg" => "Vínculo removido."]);
} else {
    echo json_encode(["status" => "erro", "msg" => "Erro ao remover."]);
}
$conn->close();
?>