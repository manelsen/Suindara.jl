package main

import "github.com/gofiber/fiber/v2"

func main() {
    app := fiber.New(fiber.Config{
        DisableStartupMessage: true,
        Prefork:               false, // Prefork is better but harder to manage process kill in simplistic bench script
    })

    app.Get("/", func(c *fiber.Ctx) error {
        return c.JSON(fiber.Map{"message": "Hello World"})
    })

    app.Listen(":8090")
}
