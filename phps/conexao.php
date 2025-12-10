<?php
// Configurações da Hospedagem
$host = "localhost"; 
$user = "meindica_guilhermehost"; 
$pass = "Gasper10*123"; 
$db   = "meindica_rastreio"; 

$conn = new mysqli($host, $user, $pass, $db);

// Verifica erros e configura charset para evitar problemas
if ($conn->connect_error) {
    die("Falha na conexao: " . $conn->connect_error);
}
$conn->set_charset("utf8");
?>