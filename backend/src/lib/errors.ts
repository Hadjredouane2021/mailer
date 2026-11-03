/** Erreur métier renvoyée telle quelle à l'app (statut HTTP + message lisible). */
export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}
