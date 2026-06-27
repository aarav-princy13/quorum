"""IBM Docling — full-precision (unquantized), torch path. Two flavours:

  * docling                — the standard Docling pipeline (layout + TableFormer
                             table structure + OCR backend). NOT a single VLM.
  * granite_docling_full   — granite-docling 258M VLM at full precision (transformers),
                             to check whether the GGUF Q hurt the quantized run (scored 17).

Needs the venv: run bench with `--venv code/ocr_bench/.venv/bin/python`.
The converter loads its models once and is reused across images (clean per-image timing;
first image folds in model load)."""

import time

from engines import Engine


class _DoclingBase(Engine):
    requires_venv = True
    heavy = False

    def available(self):
        try:
            import docling  # noqa: F401
        except Exception as e:
            return False, f"docling not importable in this interpreter: {e}"
        return True, "ok"

    def _make_converter(self):
        raise NotImplementedError

    def ocr_batch(self, image_paths):
        conv = self._make_converter()
        out = []
        for p in map(str, image_paths):
            t0 = time.perf_counter()
            try:
                res = conv.convert(p)
                text = res.document.export_to_markdown()
            except Exception as e:
                text = f"[docling error: {e}]"
            out.append({"text": text, "seconds": time.perf_counter() - t0})
        return out


class DoclingStandard(_DoclingBase):
    name = "docling"

    def _make_converter(self):
        # This docling defaults OCR to PP-OCRv6 (unconfigured here) -> pin EasyOCR,
        # docling's classic default backend, for a representative "plain docling" run.
        from docling.datamodel.base_models import InputFormat
        from docling.datamodel.pipeline_options import EasyOcrOptions, PdfPipelineOptions
        from docling.document_converter import DocumentConverter, ImageFormatOption

        opts = PdfPipelineOptions()
        opts.do_ocr = True
        opts.do_table_structure = True
        opts.ocr_options = EasyOcrOptions()
        return DocumentConverter(
            format_options={
                InputFormat.IMAGE: ImageFormatOption(pipeline_options=opts),
            }
        )


class DoclingGranite(_DoclingBase):
    name = "granite_docling_full"  # unquantized granite-docling 258M via transformers

    def _make_converter(self):
        from docling.datamodel import vlm_model_specs
        from docling.datamodel.base_models import InputFormat
        from docling.datamodel.pipeline_options import VlmPipelineOptions
        from docling.document_converter import DocumentConverter, ImageFormatOption
        from docling.pipeline.vlm_pipeline import VlmPipeline

        opts = VlmPipelineOptions(vlm_options=vlm_model_specs.GRANITEDOCLING_TRANSFORMERS)
        return DocumentConverter(
            format_options={
                InputFormat.IMAGE: ImageFormatOption(
                    pipeline_cls=VlmPipeline, pipeline_options=opts
                ),
            }
        )
