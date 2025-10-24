# Forge 

Forge is a framework inspired by Symfony, created by Altec Sistemas for rapid development of APIs and apps in Dart. It provides a modular structure with Dependency Injection, Serialization, Validation, and more.

baseado no meu codigo , crie um readme do meu forge

vamos começar passando oque é , depois vamos explicar como usar

no caso basca criar um bundle usando @AutoBundle e no main chamar o kernel e adicionar o bundle nele

uma vez feito isso é so criar os controllers e os serviços usando annotations que o build runner ira gerar os registros no injector

depois vamos explicar como usar serializer e o validator , os dois podemos usar com controller usando @MapRequestPayload , que valida e deserlaiza na model e usando o serializer é so retornar o valor , podemos também validar maps com validador passando Collection direto no validador validade or throw , ou serializer com denormalize ou serialize , passando o tipo genérico é claro

temos os metadados é basicamente um tipo de reflexão interna do gerador , que para usar é so criar uma annotation e implementar capabilities

evite ser verboso e prolixo , evite emojis e escreva em ingles