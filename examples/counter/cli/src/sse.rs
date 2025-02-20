use eyre::{bail, eyre, Result};
use futures::{stream, AsyncReadExt};

use shared::sse::{SseRequest, SseResponse};

pub async fn request(
    SseRequest { url }: &SseRequest,
) -> Result<impl futures::TryStream<Ok = SseResponse>> {
    let mut response = surf::get(url)
        .await
        .map_err(|e| eyre!("get {url}: error {e}"))?;

    let status = response.status().into();

    let body = if let 200..=299 = status {
        response.take_body()
    } else {
        bail!("get {url}: status {status}");
    };

    let body = body.into_reader();

    Ok(Box::pin(stream::try_unfold(body, |mut body| async {
        let mut buf = [0; 1024];

        match body.read(&mut buf).await {
            Ok(n) if n == 0 => Ok(None),
            Ok(n) => {
                let chunk = SseResponse::Chunk(buf[0..n].to_vec());
                Ok(Some((chunk, body)))
            }
            Err(e) => bail!("failed to read from http response; err = {:?}", e),
        }
    })))
}
